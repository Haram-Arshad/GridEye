RATE_PER_UNIT  = 33.10  
TAX_PERCENTAGE = 30.0    
FIXED_CHARGES  = 735.0   


def bill_breakdown(units: float) -> dict:
    """Units se poora itemised bill nikalta hai."""
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
    """Firestore ke billEst / amount ke liye: poore rupees mein total."""
    return int(round(bill_breakdown(units)["total_bill"]))


if __name__ == "__main__":

    print(bill_breakdown(206))
    print("206 units ->", total_bill(206), "(actual GEPCO bill: Rs 9,427 incl FPA adjustments)")