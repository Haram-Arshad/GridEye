# Task 8: Stage-2 Fault Classification

def classify_anomaly(data):
    
    voltage = data["voltage"]
    current = data["current"]
    
    # Threshold values for drop detection
    voltage_drop = voltage < 210
    current_drop = current < 5

    # Classification logic
    if voltage_drop and current_drop:
        return "Technical Fault"
    
    elif current_drop and not voltage_drop:
        return "Electricity Theft"
    
    else:
        return "Normal"


# Example test data
sample_data = {
    "voltage": 220,
    "current": 3
}

result = classify_anomaly(sample_data)

print("Classification Result:", result)