import pytest

from app.services.video_validation import (
    MAX_VIDEO_DURATION_EXCLUSIVE,
    mp4_duration_seconds,
    validate_video_duration_seconds,
)


def test_validate_video_duration_seconds_allows_up_to_59():
    validate_video_duration_seconds(0)
    validate_video_duration_seconds(59.0)
    validate_video_duration_seconds(59.999)


def test_validate_video_duration_seconds_rejects_60_plus():
    with pytest.raises(ValueError, match="less than 1 minute"):
        validate_video_duration_seconds(60.0)
    with pytest.raises(ValueError, match="less than 1 minute"):
        validate_video_duration_seconds(120.5)


def test_mp4_duration_seconds_reads_mvhd():
    mvhd_payload = (
        b"\x00"
        + b"\x00" * 3
        + b"\x00" * 8
        + b"\x00\x00\x03\xe8"
        + b"\x00\x00\xaf\xc8"
    )
    mvhd_atom = (8 + len(mvhd_payload)).to_bytes(4, "big") + b"mvhd" + mvhd_payload
    moov_atom = (8 + len(mvhd_atom)).to_bytes(4, "big") + b"moov" + mvhd_atom
    ftyp = (16).to_bytes(4, "big") + b"ftyp" + b"mp42" + b"\x00" * 4
    data = ftyp + moov_atom
    measured = mp4_duration_seconds(data)
    assert measured == pytest.approx(45.0)


def test_max_video_duration_exclusive_is_60():
    assert MAX_VIDEO_DURATION_EXCLUSIVE == 60.0
