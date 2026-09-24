RATE_PER_UNIT  = 50.0    # Rs per kWh
TAX_PERCENTAGE = 17.0    # % of energy charges
FIXED_CHARGES  = 150.0   # Rs per bill


def bill_breakdown(units: float) -> dict:
    if units < 0:
        raise ValueError("units cannot be negative.")
    units          = round(float(units), 2)
    energy_charges = round(units * RATE_PER_UNIT, 2)
    tax_amount     = round(energy_charges * TAX_PERCENTAGE / 100, 2)
    total          = round(energy_charges + tax_amount + FIXED_CHARGES, 2)
    return {
        "units_consumed": units,
        "energy_charges": energy_charges,
        "tax_amount":     tax_amount,
        "fixed_charges":  FIXED_CHARGES,
        "total_bill":     total,
    }


def total_bill(units: float) -> int:
    return int(round(bill_breakdown(units)["total_bill"]))


if __name__ == "__main__":
    print(bill_breakdown(166.3))
    assert total_bill(166.3) == 9879
    print("OK: 166.3 units ->", total_bill(166.3))