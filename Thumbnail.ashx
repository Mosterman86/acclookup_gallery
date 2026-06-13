<%@ WebHandler Language="C#" Class="ThumbnailHandler" %>

using System;
using System.Diagnostics;
using System.IO;
using System.Web;

public class ThumbnailHandler : IHttpHandler
{
    public void ProcessRequest(HttpContext context)
    {
        string imagePath = context.Request.QueryString["path"];

        if (string.IsNullOrEmpty(imagePath) || !File.Exists(imagePath))
        {
            context.Response.StatusCode = 404;
            context.Response.Write("Image not found or path missing.");
            return;
        }

        string magickExe = @"C:\Program Files\ImageMagick-7.1.2-Q8\magick.exe";

        var startInfo = new ProcessStartInfo
        {
            FileName = magickExe,
            Arguments = "\"" + imagePath + "\" -thumbnail 200x200 jpg:-", // output to stdout
            CreateNoWindow = true,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };

        try
        {
            using (var proc = Process.Start(startInfo))
            {
                using (var ms = new MemoryStream())
                {
                    proc.StandardOutput.BaseStream.CopyTo(ms);
                    proc.WaitForExit();

                    if (proc.ExitCode != 0 || ms.Length == 0)
                    {
                        string error = proc.StandardError.ReadToEnd();
                        context.Response.StatusCode = 500;
                        context.Response.ContentType = "text/plain";
                        context.Response.Write("Thumbnail generation failed.\n" + error);
                        return;
                    }

                    // Set cache headers so browser caches thumbnails
                    context.Response.ContentType = "image/jpeg";
                    context.Response.Cache.SetCacheability(HttpCacheability.Public);
                    context.Response.Cache.SetExpires(DateTime.UtcNow.AddDays(30)); // 30-day browser cache
                    context.Response.Cache.SetLastModified(File.GetLastWriteTimeUtc(imagePath));
                    context.Response.BinaryWrite(ms.ToArray());
                }
            }
        }
        catch (Exception ex)
        {
            context.Response.StatusCode = 500;
            context.Response.ContentType = "text/plain";
            context.Response.Write("Exception while running ImageMagick: " + ex.Message);
        }
    }

    public bool IsReusable { get { return true; } }
}
