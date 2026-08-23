"""Admin/staff path matching for network guards."""

from app.middleware.admin_paths import is_admin_protected_path


def test_admin_paths_include_core_admin_routes():
    assert is_admin_protected_path("/admin/users")
    assert is_admin_protected_path("/admin/")
    assert is_admin_protected_path("/admin")


def test_admin_paths_include_community_moderation():
    assert is_admin_protected_path("/community/admin/cities")
    assert is_admin_protected_path("/community/admin/cities/casablanca")


def test_admin_paths_ignore_public_routes():
    assert not is_admin_protected_path("/community/cities")
    assert not is_admin_protected_path("/auth/login")
    assert not is_admin_protected_path("/products")
