using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace ObsidianGames.AdminTool;

public class MainForm : Form
{
    private const string HomeUrl = "https://admin.obsidiangames.net/";

    private readonly WebView2 _webView = new() { Dock = DockStyle.Fill };

    public MainForm()
    {
        Text = "OBSIDIAN GAMES ADMIN TOOL";
        Icon = LoadEmbeddedIcon();
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(1280, 800);
        MinimumSize = new Size(720, 480);
        BackColor = Color.FromArgb(14, 15, 18);
        KeyPreview = true;

        // The WebView fills the whole client area - no status/URL bar.
        Controls.Add(_webView);

        Load += async (_, _) => await InitializeAsync();
    }

    private static Icon LoadEmbeddedIcon()
    {
        try
        {
            // Reads the icon embedded from app.ico at build time.
            return Icon.ExtractAssociatedIcon(Environment.ProcessPath ?? Application.ExecutablePath)
                   ?? SystemIcons.Application;
        }
        catch (Exception ex)
        {
            AppPaths.Log($"Icon load failed: {ex.Message}");
            return SystemIcons.Application;
        }
    }

    private async Task InitializeAsync()
    {
        try
        {
            AppPaths.EnsureCreated();

            var envOptions = new CoreWebView2EnvironmentOptions();
            var env = await CoreWebView2Environment.CreateAsync(
                userDataFolder: AppPaths.WebView2Profile,
                browserExecutableFolder: null,
                options: envOptions);

            await _webView.EnsureCoreWebView2Async(env);

            var core = _webView.CoreWebView2;
            core.Settings.IsStatusBarEnabled = false;
            core.Settings.AreDefaultContextMenusEnabled = false;
            core.Settings.IsZoomControlEnabled = true;
            core.Settings.IsPasswordAutosaveEnabled = true;
            core.Settings.IsGeneralAutofillEnabled = true;

            // Open links that target a new tab inside this same window so the
            // app never spawns a stray external browser.
            core.NewWindowRequested += (_, e) =>
            {
                e.Handled = true;
                core.Navigate(e.Uri);
            };

            core.NavigationCompleted += (_, e) =>
            {
                AppPaths.Log($"Navigation completed: {core.Source} (ok={e.IsSuccess})");
                if (!e.IsSuccess)
                {
                    MessageBox.Show(
                        $"Could not load the admin tool.\n\n{core.Source}\n\nCheck your internet connection.",
                        Text, MessageBoxButtons.OK, MessageBoxIcon.Warning);
                }
            };

            AppPaths.Log($"WebView2 ready: {core.Environment.BrowserVersionString}");
            core.Navigate(HomeUrl);
        }
        catch (Exception ex)
        {
            AppPaths.Log($"WebView2 init failed: {ex}");
            MessageBox.Show(
                "The built-in browser engine (WebView2) could not start.\n\n" +
                $"{ex.Message}\n\nDetails were written to:\n{AppPaths.LogFile}",
                Text, MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        try { _webView.Dispose(); } catch { /* best effort */ }
        base.OnFormClosing(e);
    }
}
