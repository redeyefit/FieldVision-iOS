def mock_vision_output(filename: str) -> dict:
    """Deterministic mock tags used in SIM_MODE."""
    return {
        "file": filename,
        "trade": "mock-trade",
        "completion": "0%",
        "notes": "simulated"
    }
