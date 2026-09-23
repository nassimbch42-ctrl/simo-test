using SimoTest.Core.Diagnostics;

Console.OutputEncoding = System.Text.Encoding.UTF8;
Console.Title = "SIMO TEST";
Console.ForegroundColor = ConsoleColor.Green;
Console.WriteLine("""
   ███████╗██╗███╗   ███╗ ██████╗
   ██╔════╝██║████╗ ████║██╔═══██╗
   ███████╗██║██╔████╔██║██║   ██║
   ╚════██║██║██║╚██╔╝██║██║   ██║
   ███████║██║██║ ╚═╝ ██║╚██████╔╝
   ╚══════╝╚═╝╚═╝     ╚═╝ ╚═════╝
""");
Console.ResetColor();
Console.WriteLine("  S I M O   T E S T");
Console.WriteLine("  // PROFESSIONAL PC DIAGNOSTICS //");
Console.WriteLine();
Console.WriteLine("Core diagnostic contract loaded.");
Console.WriteLine("Status model: NORMAL / ATTENTION / ANOMALY_DETECTED / NOT_DETERMINED / NOT_SUPPORTED");
Console.WriteLine("The PowerShell runner currently provides the Windows hardware collectors.");
