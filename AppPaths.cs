using System.Runtime.InteropServices;

namespace ObsidianGames.AdminTool;

/// <summary>
/// Keeps every runtime file this app produces (WebView2 profile, cache, cookies,
/// logs) inside %APPDATA%\ObsidianGamesAdminTool instead of next to the .exe.
/// </summary>
internal static class AppPaths
{
    /// <summary>Folder name used under %APPDATA%\Roaming.</summary>
    public const string FolderName = "ObsidianGamesAdminTool";

    /// <summary>%APPDATA%\ObsidianGamesAdminTool</summary>
    public static string DataRoot { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        FolderName);

    /// <summary>%APPDATA%\ObsidianGamesAdminTool\WebView2</summary>
    public static string WebView2Profile { get; } = Path.Combine(DataRoot, "WebView2");

    /// <summary>%APPDATA%\ObsidianGamesAdminTool\logs</summary>
    public static string Logs { get; } = Path.Combine(DataRoot, "logs");

    public static string LogFile { get; } = Path.Combine(Logs, "app.log");

    /// <summary>Creates the folders on first run and returns them.</summary>
    public static void EnsureCreated()
    {
        Directory.CreateDirectory(DataRoot);
        Directory.CreateDirectory(WebView2Profile);
        Directory.CreateDirectory(Logs);
    }

    /// <summary>Append-only log so crashes can be diagnosed without a console.</summary>
    public static void Log(string message)
    {
        try
        {
            EnsureCreated();
            var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} {message}{Environment.NewLine}";
            File.AppendAllText(LogFile, line);
        }
        catch
        {
            // Logging must never take the app down.
        }
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern int SHGetFolderPath(IntPtr hwnd, int csidl, IntPtr hToken, int flags, [Out] char[] path);

    /// <summary>Resolves %APPDATA% without depending on a WinForms handle.</summary>
    public static string RoamingAppData()
    {
        var buffer = new char[260];
        SHGetFolderPath(IntPtr.Zero, 0x001A, IntPtr.Zero, 0, buffer);
        var value = new string(buffer).TrimEnd('\0');
        return string.IsNullOrWhiteSpace(value)
            ? Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData)
            : value;
    }
}
