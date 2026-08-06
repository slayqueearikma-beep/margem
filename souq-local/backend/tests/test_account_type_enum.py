from app.models import AccountType, account_type_enum


def test_account_type_values_for_postgres():
    values = account_type_enum.enums
    assert values == ["customer", "provider"]
    assert AccountType.CUSTOMER.value == "customer"
    assert AccountType.PROVIDER.value == "provider"
