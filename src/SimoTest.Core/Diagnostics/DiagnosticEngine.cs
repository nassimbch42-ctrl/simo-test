namespace SimoTest.Core.Diagnostics;

public sealed class DiagnosticEngine(IEnumerable<IDiagnosticModule> modules)
{
    private readonly IReadOnlyList<IDiagnosticModule> _modules = modules.ToList();

    public async Task<IReadOnlyList<DiagnosticResult>> RunAsync(CancellationToken cancellationToken = default)
    {
        var results = new List<DiagnosticResult>(_modules.Count);
        foreach (var module in _modules)
        {
            cancellationToken.ThrowIfCancellationRequested();
            results.Add(await module.RunAsync(cancellationToken));
        }
        return results;
    }
}
