namespace ObsidianGames.AdminTool;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        AppPaths.EnsureCreated();
        AppPaths.Log($"--- launch v{Application.ProductVersion} ---");
        AppPaths.Log($"exe : {Environment.ProcessPath}");
        AppPaths.Log($"data: {AppPaths.DataRoot}");

        Application.ThreadException += (_, e) => AppPaths.Log($"UI error: {e.Exception}");
        AppDomain.CurrentDomain.UnhandledException += (_, e) =>
            AppPaths.Log($"Fatal: {e.ExceptionObject}");
        Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);

        try
        {
            Application.Run(new MainForm());
        }
        catch (Exception ex)
        {
            AppPaths.Log($"Fatal on startup: {ex}");
            MessageBox.Show(
                $"The application failed to start:\n\n{ex.Message}",
                "OBSIDIAN GAMES ADMIN TOOL",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }

        AppPaths.Log("--- exit ---");
    }
}
