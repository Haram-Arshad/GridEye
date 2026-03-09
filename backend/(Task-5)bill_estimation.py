# Bill Estimation Logic

def estimate_bill(previous_reading, current_reading, rate_per_unit):

    units = current_reading - previous_reading
    bill = units * rate_per_unit

    return units, bill


# Example values
previous = 1200
current = 1350
rate = 50

units, bill = estimate_bill(previous, current, rate)

print("Units Consumed:", units)
print("Estimated Bill:", bill)