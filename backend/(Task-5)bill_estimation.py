from datetime import datetime


RATE_PER_UNIT   = 50.0
TAX_PERCENTAGE  = 17.0
FIXED_CHARGES   = 150.0


def calculate_bill(previous_reading: float, current_reading: float,
                   rate: float, tax_pct: float, fixed_charges: float) -> dict:

    if current_reading < previous_reading:
        raise ValueError("Current reading cannot be less than previous reading.")

    units          = round(current_reading - previous_reading, 2)
    energy_charges = round(units * rate, 2)
    tax_amount     = round(energy_charges * tax_pct / 100, 2)
    total_bill     = round(energy_charges + tax_amount + fixed_charges, 2)

    return {
        "units_consumed"  : units,
        "energy_charges"  : energy_charges,
        "tax_amount"      : tax_amount,
        "fixed_charges"   : fixed_charges,
        "total_bill"      : total_bill,
    }


def display_bill(previous: float, current: float, result: dict):
    print("\n" + "=" * 50)
    print("  GridEye — Consumer Bill Estimation")
    print("=" * 50)
    print(f"  Generated On      : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 50)
    print(f"  Previous Reading  : {previous:.2f} kWh")
    print(f"  Current  Reading  : {current:.2f} kWh")
    print("-" * 50)
    print(f"  Units Consumed    : {result['units_consumed']:.2f} kWh")
    print(f"  Rate per Unit     : Rs. {RATE_PER_UNIT:.2f}")
    print(f"  Energy Charges    : Rs. {result['energy_charges']:.2f}")
    print(f"  Tax ({TAX_PERCENTAGE:.0f}%)          : Rs. {result['tax_amount']:.2f}")
    print(f"  Fixed Charges     : Rs. {result['fixed_charges']:.2f}")
    print("-" * 50)
    print(f"  Total Bill        : Rs. {result['total_bill']:.2f}")
    print("=" * 50 + "\n")


def run_bill_estimation(previous_reading: float, current_reading: float):
    try:
        result = calculate_bill(
            previous_reading,
            current_reading,
            RATE_PER_UNIT,
            TAX_PERCENTAGE,
            FIXED_CHARGES
        )
        display_bill(previous_reading, current_reading, result)

    except ValueError as e:
        print(f"\nError: {e}\n")


if __name__ == "__main__":
    PREVIOUS_READING = 1200.0
    CURRENT_READING  = 1350.0

    run_bill_estimation(PREVIOUS_READING, CURRENT_READING)
