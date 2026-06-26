using System.Globalization;
using System.Text;
using System.Xml.Linq;

namespace Loopline.Server.Usbmux;

/// <summary>
/// Just enough XML-plist support to talk to usbmuxd: build request dictionaries
/// and parse replies into plain CLR objects (Dictionary, List, string, long, bool).
/// </summary>
public static class PlistLite
{
    private const string Header =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
        "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" " +
        "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n";

    public static byte[] Build(Dictionary<string, object> dict)
    {
        var sb = new StringBuilder(Header);
        sb.Append("<plist version=\"1.0\">");
        WriteValue(sb, dict);
        sb.Append("</plist>");
        return Encoding.UTF8.GetBytes(sb.ToString());
    }

    private static void WriteValue(StringBuilder sb, object value)
    {
        switch (value)
        {
            case Dictionary<string, object> d:
                sb.Append("<dict>");
                foreach (var kv in d)
                {
                    sb.Append("<key>").Append(Escape(kv.Key)).Append("</key>");
                    WriteValue(sb, kv.Value);
                }
                sb.Append("</dict>");
                break;
            case string s:
                sb.Append("<string>").Append(Escape(s)).Append("</string>");
                break;
            case bool b:
                sb.Append(b ? "<true/>" : "<false/>");
                break;
            case int i:
                sb.Append("<integer>").Append(i.ToString(CultureInfo.InvariantCulture)).Append("</integer>");
                break;
            case long l:
                sb.Append("<integer>").Append(l.ToString(CultureInfo.InvariantCulture)).Append("</integer>");
                break;
            default:
                sb.Append("<string>").Append(Escape(value?.ToString() ?? "")).Append("</string>");
                break;
        }
    }

    public static object Parse(byte[] xml)
    {
        var text = Encoding.UTF8.GetString(xml);
        var doc = XDocument.Parse(text);
        var plist = doc.Root; // <plist>
        var first = plist?.Elements().FirstOrDefault();
        return first == null ? null : ParseElement(first);
    }

    private static object ParseElement(XElement el)
    {
        switch (el.Name.LocalName)
        {
            case "dict":
                var dict = new Dictionary<string, object>();
                var children = el.Elements().ToList();
                for (int i = 0; i + 1 < children.Count; i += 2)
                {
                    var key = children[i].Value;
                    dict[key] = ParseElement(children[i + 1]);
                }
                return dict;
            case "array":
                return el.Elements().Select(ParseElement).ToList();
            case "string":
                return el.Value;
            case "integer":
                return long.TryParse(el.Value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var n) ? n : 0L;
            case "true":
                return true;
            case "false":
                return false;
            case "data":
                return Convert.FromBase64String(el.Value.Trim());
            default:
                return el.Value;
        }
    }

    private static string Escape(string s) =>
        s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;");
}
