namespace SimoTest.Core.Diagnostics;

public sealed record Measurement(string Name, string? Value, string? Unit, string Source);
public sealed record DiagnosticEvidence(string Code, string Message, string Source, bool Confirmed);

public sealed record DiagnosticResult(
    string Component,
    DiagnosticStatus Status,
    ConfidenceLevel Confidence,
    IReadOnlyList<Measurement> Measurements,
    IReadOnlyList<DiagnosticEvidence> Evidence,
    string? Explanation);

public interface IDiagnosticModule
{
    string Id { get; }
    string Name { get; }
    Task<DiagnosticResult> RunAsync(CancellationToken cancellationToken = default);
}
