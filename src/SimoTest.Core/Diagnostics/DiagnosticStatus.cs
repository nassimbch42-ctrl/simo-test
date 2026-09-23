namespace SimoTest.Core.Diagnostics;

public enum DiagnosticStatus
{
    Normal,
    Attention,
    AnomalyDetected,
    NotDetermined,
    NotSupported
}

public enum ConfidenceLevel
{
    Low,
    Medium,
    High
}
