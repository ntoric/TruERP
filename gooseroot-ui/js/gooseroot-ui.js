/* Gooseroot UI kit runtime: icons, logos and the Lens loader as inline SVG. No dependencies, no network. */
(function () {
  var ICONS = {"grid": "<rect x=\"4\" y=\"4\" width=\"7\" height=\"7\" rx=\"2\"/><rect x=\"13\" y=\"4\" width=\"7\" height=\"7\" rx=\"2\"/><rect x=\"4\" y=\"13\" width=\"7\" height=\"7\" rx=\"2\"/><rect x=\"13\" y=\"13\" width=\"7\" height=\"7\" rx=\"2\"/>", "user": "<circle cx=\"12\" cy=\"8\" r=\"4\"/><path d=\"M4 20c1.5-4 4.5-6 8-6s6.5 2 8 6\"/>", "users": "<circle cx=\"9\" cy=\"8\" r=\"3.5\"/><path d=\"M2.5 19c1-3.4 3.5-5 6.5-5s5.5 1.6 6.5 5\"/><path d=\"M16 4.5a3.5 3.5 0 0 1 0 7M18 14c1.8.6 3 2.2 3.6 5\"/>", "bell": "<path d=\"M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z\"/><path d=\"M10 20.5a2 2 0 0 0 4 0\"/>", "calendar": "<rect x=\"3.5\" y=\"5\" width=\"17\" height=\"15.5\" rx=\"3\"/><path d=\"M3.5 10h17M8 3v4M16 3v4\"/>", "inbox": "<path d=\"M4 13l2.5-7.5h11L20 13v5.5a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z\"/><path d=\"M4 13h4.5l1 2.5h5l1-2.5H20\"/>", "edit": "<path d=\"M4 20h4L19 9l-4-4L4 16z\"/><path d=\"M13.5 6.5l4 4\"/>", "settings": "<circle cx=\"12\" cy=\"12\" r=\"3\"/><path d=\"M12 2.5v3M12 18.5v3M4.2 6.2l2.1 2.1M17.7 15.7l2.1 2.1M2.5 12h3M18.5 12h3M4.2 17.8l2.1-2.1M17.7 8.3l2.1-2.1\"/>", "search": "<circle cx=\"11\" cy=\"11\" r=\"6.5\"/><path d=\"M20 20l-4.2-4.2\"/>", "plus": "<path d=\"M12 5v14M5 12h14\"/>", "minus": "<path d=\"M5 12h14\"/>", "chevron-left": "<path d=\"M15 5l-7 7 7 7\"/>", "chevron-right": "<path d=\"M9 5l7 7-7 7\"/>", "chevron-down": "<path d=\"M5 9l7 7 7-7\"/>", "check": "<path d=\"M5 12.5l4.5 4.5L19 7.5\"/>", "x": "<path d=\"M6 6l12 12M18 6L6 18\"/>", "trash": "<path d=\"M4 7h16M9 7V4.5h6V7M6.5 7l1 13h9l1-13\"/><path d=\"M10 11v5M14 11v5\"/>", "more": "<circle cx=\"5\" cy=\"12\" r=\"1.3\" fill=\"currentColor\" stroke=\"none\"/><circle cx=\"12\" cy=\"12\" r=\"1.3\" fill=\"currentColor\" stroke=\"none\"/><circle cx=\"19\" cy=\"12\" r=\"1.3\" fill=\"currentColor\" stroke=\"none\"/>", "clip": "<path d=\"M20 11.5l-8 8a5 5 0 0 1-7-7l8.5-8.5a3.3 3.3 0 0 1 4.7 4.7L9.7 17.2a1.7 1.7 0 0 1-2.4-2.4L15 7\"/>", "chat": "<path d=\"M4 18.5V7a3 3 0 0 1 3-3h10a3 3 0 0 1 3 3v7a3 3 0 0 1-3 3H8z\"/>", "share": "<circle cx=\"6\" cy=\"12\" r=\"2.5\"/><circle cx=\"18\" cy=\"6\" r=\"2.5\"/><circle cx=\"18\" cy=\"18\" r=\"2.5\"/><path d=\"M8.2 10.8l7.6-3.6M8.2 13.2l7.6 3.6\"/>", "download": "<path d=\"M12 4v11M7 10.5l5 5 5-5M5 20h14\"/>", "upload": "<path d=\"M12 16V5M7 9.5l5-5 5 5M5 20h14\"/>", "sun": "<circle cx=\"12\" cy=\"12\" r=\"4\"/><path d=\"M12 2.5v2M12 19.5v2M4.6 4.6l1.4 1.4M18 18l1.4 1.4M2.5 12h2M19.5 12h2M4.6 19.4L6 18M18 6l1.4-1.4\"/>", "moon": "<path d=\"M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5z\"/>", "clock": "<circle cx=\"12\" cy=\"12\" r=\"8.5\"/><path d=\"M12 7.5V12l3 2\"/>", "refresh": "<path d=\"M20 11a8 8 0 0 0-14.5-4.5L4 8.5M4 13a8 8 0 0 0 14.5 4.5L20 15.5\"/><path d=\"M4 4v4.5h4.5M20 20v-4.5h-4.5\"/>", "folder": "<path d=\"M3.5 7a2 2 0 0 1 2-2h4l2 2.5h7a2 2 0 0 1 2 2V17a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z\"/>", "chart": "<path d=\"M4 20V10M10 20V4M16 20v-7M21 20H3\"/>", "code": "<path d=\"M8.5 7L3.5 12l5 5M15.5 7l5 5-5 5M13.5 4.5l-3 15\"/>", "phone": "<rect x=\"7\" y=\"2.5\" width=\"10\" height=\"19\" rx=\"2.5\"/><path d=\"M11 18.5h2\"/>", "monitor": "<rect x=\"3\" y=\"4\" width=\"18\" height=\"13\" rx=\"2\"/><path d=\"M8 21h8M12 17v4\"/>", "sparkle": "<path d=\"M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z\"/><path d=\"M19 15.5l.7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7z\"/>", "mail": "<rect x=\"3.5\" y=\"5.5\" width=\"17\" height=\"13\" rx=\"2.5\"/><path d=\"M4 7l8 6 8-6\"/>", "lock": "<rect x=\"5\" y=\"10.5\" width=\"14\" height=\"10\" rx=\"2.5\"/><path d=\"M8 10.5V8a4 4 0 0 1 8 0v2.5\"/>", "eye": "<path d=\"M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z\"/><circle cx=\"12\" cy=\"12\" r=\"3\"/>", "arrow-right": "<path d=\"M5 12h14M13 6l6 6-6 6\"/>", "arrow-up": "<path d=\"M12 19V5M6 11l6-6 6 6\"/>", "filter": "<path d=\"M4 5h16l-6 7.5V19l-4 1.5v-8z\"/>", "star": "<path d=\"M12 3.5l2.6 5.4 5.9.8-4.3 4.1 1 5.8L12 16.8l-5.2 2.8 1-5.8-4.3-4.1 5.9-.8z\"/>", "home": "<path d=\"M4 10.5L12 4l8 6.5V19a1.5 1.5 0 0 1-1.5 1.5h-4v-6h-5v6h-4A1.5 1.5 0 0 1 4 19z\"/>", "logout": "<path d=\"M14 4.5H6.5a2 2 0 0 0-2 2v11a2 2 0 0 0 2 2H14M10 12h10.5M17 8.5l3.5 3.5-3.5 3.5\"/>", "info": "<circle cx=\"12\" cy=\"12\" r=\"8.5\"/><path d=\"M12 11v5.5M12 7.6v.1\"/>", "alert": "<path d=\"M12 3.5L21.5 20h-19z\"/><path d=\"M12 10v4.5M12 17.4v.1\"/>", "gift": "<rect x=\"4\" y=\"9\" width=\"16\" height=\"11\" rx=\"2\"/><path d=\"M3 9h18M12 9v11M12 9c-1.5-3.5-5.5-4-5.5-1.5S10 9 12 9zM12 9c1.5-3.5 5.5-4 5.5-1.5S14 9 12 9z\"/>", "list": "<path d=\"M9 6h11M9 12h11M9 18h11M4.5 6h.1M4.5 12h.1M4.5 18h.1\"/>", "board": "<rect x=\"3.5\" y=\"4\" width=\"5\" height=\"16\" rx=\"1.5\"/><rect x=\"10\" y=\"4\" width=\"5\" height=\"11\" rx=\"1.5\"/><rect x=\"16.5\" y=\"4\" width=\"4\" height=\"7\" rx=\"1.5\"/>", "workflow": "<rect x=\"3\" y=\"4\" width=\"7\" height=\"6\" rx=\"1.5\"/><rect x=\"14\" y=\"14\" width=\"7\" height=\"6\" rx=\"1.5\"/><path d=\"M6.5 10v4a3 3 0 0 0 3 3H14\"/>", "link": "<path d=\"M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1\"/>", "video": "<rect x=\"3\" y=\"6\" width=\"13\" height=\"12\" rx=\"2.5\"/><path d=\"M16 10.5l5-3v9l-5-3z\"/>", "globe": "<circle cx=\"12\" cy=\"12\" r=\"8.5\"/><path d=\"M3.5 12h17M12 3.5c2.5 2.5 3.5 5.5 3.5 8.5s-1 6-3.5 8.5c-2.5-2.5-3.5-5.5-3.5-8.5s1-6 3.5-8.5z\"/>", "credit": "<rect x=\"3\" y=\"5.5\" width=\"18\" height=\"13\" rx=\"2.5\"/><path d=\"M3 10h18M7 15h4\"/>", "cart": "<path d=\"M3 4h2.5l2.2 11h10.6l2-8H6.6\"/><circle cx=\"9.5\" cy=\"19.5\" r=\"1.5\"/><circle cx=\"17\" cy=\"19.5\" r=\"1.5\"/>", "heart": "<path d=\"M12 20s-7.5-4.6-7.5-10.2A4.3 4.3 0 0 1 12 7.2a4.3 4.3 0 0 1 7.5 2.6C19.5 15.4 12 20 12 20z\"/>", "bag": "<path d=\"M5 8h14l-1 12.5H6z\"/><path d=\"M9 8V6.5a3 3 0 0 1 6 0V8\"/>", "headphones": "<path d=\"M4 15v-3a8 8 0 0 1 16 0v3\"/><rect x=\"3.5\" y=\"14\" width=\"4.5\" height=\"6.5\" rx=\"1.5\"/><rect x=\"16\" y=\"14\" width=\"4.5\" height=\"6.5\" rx=\"1.5\"/>", "watch": "<rect x=\"6\" y=\"6.5\" width=\"12\" height=\"11\" rx=\"3\"/><path d=\"M9 6.5l.7-3.5h4.6l.7 3.5M9 17.5l.7 3.5h4.6l.7-3.5M12 10v2.5l1.5 1\"/>", "camera": "<path d=\"M4 8.5a2 2 0 0 1 2-2h2l1.5-2.5h5L16 6.5h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z\"/><circle cx=\"12\" cy=\"13\" r=\"3.5\"/>", "box": "<path d=\"M3.5 7.5L12 3l8.5 4.5v9L12 21l-8.5-4.5z\"/><path d=\"M3.5 7.5L12 12l8.5-4.5M12 12v9\"/>", "wallet": "<path d=\"M4 7a2 2 0 0 1 2-2h11v4\"/><rect x=\"4\" y=\"7\" width=\"16\" height=\"12\" rx=\"2\"/><path d=\"M16 13h4\"/>", "bank": "<path d=\"M3.5 9L12 4l8.5 5M5 9v8M9.5 9v8M14.5 9v8M19 9v8M3.5 20h17\"/>", "qr": "<rect x=\"4\" y=\"4\" width=\"6\" height=\"6\" rx=\"1\"/><rect x=\"14\" y=\"4\" width=\"6\" height=\"6\" rx=\"1\"/><rect x=\"4\" y=\"14\" width=\"6\" height=\"6\" rx=\"1\"/><path d=\"M14 14h2v2h-2zM18 18h2v2h-2zM14 18h2M18 14h2\"/>", "file": "<path d=\"M7 3.5h7l4 4V20a.5.5 0 0 1-.5.5h-10.5A1 1 0 0 1 6 19.5v-15a1 1 0 0 1 1-1z\"/><path d=\"M14 3.5V8h4\"/>", "image": "<rect x=\"3.5\" y=\"4.5\" width=\"17\" height=\"15\" rx=\"2.5\"/><circle cx=\"9\" cy=\"10\" r=\"1.8\"/><path d=\"M4 17l5-4.5 4 3.5 3-2.5 4.5 4\"/>", "layers": "<path d=\"M12 4l8.5 4.5L12 13 3.5 8.5z\"/><path d=\"M3.5 12.5L12 17l8.5-4.5M3.5 16.5L12 21l8.5-4.5\"/>", "zap": "<path d=\"M13 3L5 13.5h6L10 21l8-10.5h-6z\"/>", "palette": "<path d=\"M12 3.5a8.5 8.5 0 1 0 0 17c1.4 0 1.8-1.2 1.2-2.2-.7-1.2 0-2.8 1.5-2.8h2a3.8 3.8 0 0 0 3.8-3.8C20.5 7 16.7 3.5 12 3.5z\"/><circle cx=\"8\" cy=\"11\" r=\"1.1\"/><circle cx=\"11\" cy=\"7.5\" r=\"1.1\"/><circle cx=\"15.5\" cy=\"8.5\" r=\"1.1\"/>", "menu": "<path d=\"M4 7h16M4 12h16M4 17h16\"/>", "question": "<circle cx=\"12\" cy=\"12\" r=\"8.5\"/><path d=\"M9.6 9.5a2.5 2.5 0 0 1 4.8.8c0 1.7-2.4 2-2.4 3.7M12 16.9v.1\"/>", "phone-call": "<path d=\"M5 4h3.5l1.5 4-2 1.5a10 10 0 0 0 6.5 6.5L16 14l4 1.5V19a1.5 1.5 0 0 1-1.5 1.5A15.5 15.5 0 0 1 3.5 5.5 1.5 1.5 0 0 1 5 4z\"/>"};
  var WORDMARK = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1020.2 240.0\"><defs><linearGradient id=\"__U__g\" gradientUnits=\"userSpaceOnUse\" x1=\"28\" y1=\"0\" x2=\"4777\" y2=\"0\"><stop offset=\"0\" stop-color=\"#F0140A\"/><stop offset=\"1\" stop-color=\"#B8002E\"/></linearGradient></defs><g transform=\"translate(20.00 20.00) scale(0.20640) translate(-28.00 694.00)\"><defs><mask id=\"__U__m\" maskUnits=\"userSpaceOnUse\" x=\"-100\" y=\"-1000\" width=\"4977\" height=\"1400\"><rect x=\"-100\" y=\"-1000\" width=\"4977\" height=\"1400\" fill=\"#fff\"/><path d=\"M1210.0 -460.3725447800741 A289 289 0 0 1 1210.0 -97.62745521992585 A289 289 0 0 1 1210.0 -460.3725447800741 Z M3851.0 -460.3725447800741 A289 289 0 0 1 3851.0 -97.62745521992585 A289 289 0 0 1 3851.0 -460.3725447800741 Z \" fill=\"#000\" stroke=\"#000\" stroke-width=\"44\" stroke-linejoin=\"round\"/></mask></defs><path fill=\"url(#__U__g)\" fill-rule=\"evenodd\" d=\"M446 -479V-558H617V-1Q617 76 586.5 138.5Q556 201 493.5 238.0Q431 275 338 275Q214 275 137.0 216.5Q60 158 49 58H218Q226 90 256.0 108.5Q286 127 330 127Q383 127 414.5 96.5Q446 66 446 -1V-80Q421 -41 377.0 -16.5Q333 8 274 8Q205 8 149.0 -27.5Q93 -63 60.5 -128.5Q28 -194 28 -280Q28 -366 60.5 -431.0Q93 -496 149.0 -531.0Q205 -566 274 -566Q333 -566 377.5 -542.0Q422 -518 446 -479ZM324 -417Q273 -417 237.5 -380.5Q202 -344 202 -280Q202 -216 237.5 -178.5Q273 -141 324 -141Q375 -141 410.5 -178.0Q446 -215 446 -279Q446 -343 410.5 -380.0Q375 -417 324 -417ZM1774 -183H1943Q1946 -154 1970.0 -136.0Q1994 -118 2029 -118Q2061 -118 2078.5 -130.5Q2096 -143 2096 -163Q2096 -187 2071.0 -198.5Q2046 -210 1990 -224Q1930 -238 1890.0 -253.5Q1850 -269 1821.0 -302.5Q1792 -336 1792 -393Q1792 -441 1818.5 -480.5Q1845 -520 1896.5 -543.0Q1948 -566 2019 -566Q2124 -566 2184.5 -514.0Q2245 -462 2254 -376H2096Q2092 -405 2070.5 -422.0Q2049 -439 2014 -439Q1984 -439 1968.0 -427.5Q1952 -416 1952 -396Q1952 -372 1977.5 -360.0Q2003 -348 2057 -336Q2119 -320 2158.0 -304.5Q2197 -289 2226.5 -254.5Q2256 -220 2257 -162Q2257 -113 2229.5 -74.5Q2202 -36 2150.5 -14.0Q2099 8 2031 8Q1958 8 1901.0 -17.0Q1844 -42 1811.0 -85.5Q1778 -129 1774 -183ZM2873 -238H2486Q2490 -186 2519.5 -158.5Q2549 -131 2592 -131Q2656 -131 2681 -185H2863Q2849 -130 2812.5 -86.0Q2776 -42 2721.0 -17.0Q2666 8 2598 8Q2516 8 2452.0 -27.0Q2388 -62 2352.0 -127.0Q2316 -192 2316 -279Q2316 -366 2351.5 -431.0Q2387 -496 2451.0 -531.0Q2515 -566 2598 -566Q2679 -566 2742.0 -532.0Q2805 -498 2840.5 -435.0Q2876 -372 2876 -288Q2876 -264 2873 -238ZM2701 -333Q2701 -377 2671.0 -403.0Q2641 -429 2596 -429Q2553 -429 2523.5 -404.0Q2494 -379 2487 -333ZM3300 -564V-383H3253Q3189 -383 3157.0 -355.5Q3125 -328 3125 -259V0H2954V-558H3125V-465Q3155 -511 3200.0 -537.5Q3245 -564 3300 -564ZM4756 -145V0H4669Q4576 0 4524.0 -45.5Q4472 -91 4472 -194V-416H4404V-558H4472V-694H4643V-558H4755V-416H4643V-192Q4643 -167 4655.0 -156.0Q4667 -145 4695 -145Z M696 -279 a289 289 0 1 0 578 0 a289 289 0 1 0 -578 0 Z M857 -279 a128 128 0 1 1 256 0 a128 128 0 1 1 -256 0 Z M1146 -279 a289 289 0 1 0 578 0 a289 289 0 1 0 -578 0 Z M1307 -279 a128 128 0 1 1 256 0 a128 128 0 1 1 -256 0 Z M3337 -279 a289 289 0 1 0 578 0 a289 289 0 1 0 -578 0 Z M3498 -279 a128 128 0 1 1 256 0 a128 128 0 1 1 -256 0 Z M3787 -279 a289 289 0 1 0 578 0 a289 289 0 1 0 -578 0 Z M3948 -279 a128 128 0 1 1 256 0 a128 128 0 1 1 -256 0 Z \" mask=\"url(#__U__m)\"/><path fill=\"none\" d=\"M1210.0 -460.3725447800741 A289 289 0 0 1 1210.0 -97.62745521992585 A289 289 0 0 1 1210.0 -460.3725447800741 Z M3851.0 -460.3725447800741 A289 289 0 0 1 3851.0 -97.62745521992585 A289 289 0 0 1 3851.0 -460.3725447800741 Z \"/></g></svg>";
  var SYMBOL = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 563.6 330.0\"><defs><linearGradient id=\"__U__g\" gradientUnits=\"userSpaceOnUse\" x1=\"-289\" y1=\"0\" x2=\"739\" y2=\"0\"><stop offset=\"0\" stop-color=\"#F0140A\"/><stop offset=\"1\" stop-color=\"#B8002E\"/></linearGradient><mask id=\"__U__m\" maskUnits=\"userSpaceOnUse\" x=\"-349\" y=\"-349\" width=\"1148\" height=\"698\"><rect x=\"-349\" y=\"-349\" width=\"1148\" height=\"698\" fill=\"#fff\"/><path d=\"M225.0 -181.37254478007415 A289 289 0 0 1 225.0 181.37254478007415 A289 289 0 0 1 225.0 -181.37254478007415 Z\" fill=\"#000\" stroke=\"#000\" stroke-width=\"44\" stroke-linejoin=\"round\"/></mask></defs><g transform=\"translate(15.00 15.00) scale(0.51903) translate(289.00 289.00)\"><path fill=\"url(#__U__g)\" fill-rule=\"evenodd\" d=\"M-289 0 a289 289 0 1 0 578 0 a289 289 0 1 0 -578 0 Z M-128 0 a128 128 0 1 1 256 0 a128 128 0 1 1 -256 0 Z M161 0 a289 289 0 1 0 578 0 a289 289 0 1 0 -578 0 Z M322 0 a128 128 0 1 1 256 0 a128 128 0 1 1 -256 0 Z\" mask=\"url(#__U__m)\"/></g></svg>";
  var LENS = "M225.0 -181.37254478007415 A289 289 0 0 1 225.0 181.37254478007415 A289 289 0 0 1 225.0 -181.37254478007415 Z";
  var uid = 0;
  function icon(name, cls) {
    var p = ICONS[name]; if (!p) return "";
    return '<svg class="gr-i ' + (cls || "") + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + p + "</svg>";
  }
  function logo(kind) {
    // kind: wordmark | wordmark-white | wordmark-wine | symbol | symbol-white
    var id = "grl" + (++uid), s = kind.indexOf("symbol") === 0 ? SYMBOL : WORDMARK;
    s = s.split("__U__").join(id);
    if (/-white$/.test(kind)) s = s.replace(/fill="url\(#[^)]+\)"/, 'fill="#FFFFFF"');
    if (/-wine$/.test(kind)) s = s.replace(/fill="url\(#[^)]+\)"/, 'fill="#5C0012"');
    return s.replace("<svg ", '<svg role="img" aria-label="Gooseroot" ');
  }
  function lens(white) {
    var id = "grx" + (++uid), stroke = white ? "#FFFFFF" : "url(#" + id + "g)";
    return '<svg class="gr-lens" viewBox="-309 -309 1068 618" role="img" aria-label="Loading"><defs><linearGradient id="' + id + 'g" gradientUnits="userSpaceOnUse" x1="-309" y1="0" x2="759" y2="0"><stop offset="0" stop-color="#F0140A"/><stop offset="1" stop-color="#B8002E"/></linearGradient>' +
      '<mask id="' + id + 'm" maskUnits="userSpaceOnUse" x="-500" y="-500" width="1500" height="1000"><rect x="-500" y="-500" width="1500" height="1000" fill="#fff"/><path class="leaf" d="' + LENS + '" fill="#000" stroke="#000" stroke-width="44" stroke-linejoin="round"/></mask></defs>' +
      '<g mask="url(#' + id + 'm)" stroke="' + stroke + '"><g class="ga"><path class="ra" pathLength="100" d="M0 -208.5 A208.5 208.5 0 1 1 0 208.5 A208.5 208.5 0 1 1 0 -208.5"/></g><g class="gb"><path class="rb" pathLength="100" d="M450 208.5 A208.5 208.5 0 1 1 450 -208.5 A208.5 208.5 0 1 1 450 208.5"/></g></g></svg>';
  }
  function mount(root) {
    root = root || document;
    root.querySelectorAll("[data-icon]").forEach(function (el) { if (!el.firstChild) el.outerHTML = icon(el.getAttribute("data-icon"), el.className); });
    root.querySelectorAll("[data-logo]").forEach(function (el) { if (!el.firstChild) el.innerHTML = logo(el.getAttribute("data-logo")); });
    root.querySelectorAll("[data-lens]").forEach(function (el) { if (!el.firstChild) el.innerHTML = lens(el.getAttribute("data-lens") === "white"); });
    root.querySelectorAll("[data-theme-toggle]").forEach(function (seg) {
      var cur = document.documentElement.getAttribute("data-theme") || "light";
      seg.querySelectorAll("button").forEach(function (x) { x.setAttribute("aria-pressed", x.getAttribute("data-value") === cur ? "true" : "false"); });
    });
    root.querySelectorAll("[data-gr-navtoggle]").forEach(function (btn) {
      btn.addEventListener("click", function () { var nav = btn.closest(".gr-nav"); var open = nav.classList.toggle("is-open"); btn.setAttribute("aria-expanded", open ? "true" : "false"); });
    });
    root.querySelectorAll("[data-gr-drawer]").forEach(function (btn) {
      btn.addEventListener("click", function () { var host = document.getElementById(btn.getAttribute("data-gr-drawer")); if (host) host.classList.toggle("is-drawer-open"); });
    });
    root.querySelectorAll(".gr-scrim, [data-gr-drawer-close]").forEach(function (el) {
      el.addEventListener("click", function () { var host = el.closest(".is-drawer-open"); if (host) host.classList.remove("is-drawer-open"); });
    });
    root.querySelectorAll(".gr-speeddial > .gr-fab").forEach(function (fab) {
      fab.addEventListener("click", function () { var sd = fab.parentNode; var open = sd.classList.toggle("is-open"); fab.setAttribute("aria-expanded", open ? "true" : "false"); });
    });
    root.querySelectorAll("[data-gr-snack]").forEach(function (btn) {
      btn.addEventListener("click", function () { var s = document.getElementById(btn.getAttribute("data-gr-snack")); if (!s) return; s.classList.remove("is-shown"); void s.offsetWidth; s.classList.add("is-shown"); clearTimeout(s._t); s._t = setTimeout(function () { s.classList.remove("is-shown"); }, 4000); });
    });
    root.querySelectorAll(".gr-snackbar [data-gr-dismiss], .gr-banner [data-gr-dismiss], .gr-cookiebar [data-gr-dismiss], .gr-alert [data-gr-dismiss]").forEach(function (btn) {
      btn.addEventListener("click", function () { var el = btn.closest(".gr-snackbar, .gr-banner, .gr-cookiebar, .gr-alert"); if (el.classList.contains("gr-snackbar--float")) { el.classList.remove("is-shown"); return; }
        el.style.maxHeight = el.scrollHeight + "px"; void el.offsetWidth; el.classList.add("is-leaving"); setTimeout(function () { el.style.display = "none"; }, 480); });
    });
    root.querySelectorAll(".gr-range").forEach(function (r) {
      var f = function () { r.style.setProperty("--v", ((r.value - r.min) / (r.max - r.min) * 100) + "%"); }; f(); r.addEventListener("input", f);
    });
    root.querySelectorAll("[data-gr-qty]").forEach(function (q) {
      var span = q.querySelector("span");
      q.addEventListener("click", function (e) { var b = e.target.closest("button"); if (!b) return; var v = +span.textContent + (b.getAttribute("data-d") === "+" ? 1 : -1); span.textContent = Math.max(1, v); });
    });
    root.querySelectorAll(".gr-themecard input").forEach(function (r) {
      r.addEventListener("change", function () { var v = r.value; if (v === "system") v = matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"; document.documentElement.setAttribute("data-theme", v);
        document.querySelectorAll("[data-theme-toggle] button").forEach(function (x) { x.setAttribute("aria-pressed", x.getAttribute("data-value") === v ? "true" : "false"); }); });
    });

    // ---------- motion ----------
    var reduce = window.matchMedia && matchMedia("(prefers-reduced-motion: reduce)").matches;
    function countUp(el) {
      if (el._counted) return; el._counted = true;
      var raw = el.textContent, m = raw.match(/[\d,.]+/); if (!m) return;
      var num = parseFloat(m[0].replace(/,/g, "")), dec = (m[0].split(".")[1] || "").length, pre = raw.slice(0, m.index), post = raw.slice(m.index + m[0].length);
      if (reduce || !isFinite(num)) return;
      var t0 = null, dur = 1200;
      function fmt(v) { var s = v.toFixed(dec); if (/,/.test(m[0])) s = Number(s).toLocaleString("en-IN", { minimumFractionDigits: dec, maximumFractionDigits: dec }); return pre + s + post; }
      function step(ts) { if (!t0) t0 = ts; var k = Math.min(1, (ts - t0) / dur); k = 1 - Math.pow(1 - k, 3); el.textContent = fmt(num * k); if (k < 1) requestAnimationFrame(step); else el.textContent = raw; }
      el.textContent = fmt(0); requestAnimationFrame(step);
    }
    var watch = root.querySelectorAll(".gr-progress, .gr-ring, .gr-stat__value, .gr-price__amount, .gr-rsum__score > b, .gr-alert, .gr-paid, [data-gr-reveal]");
    var revealSel = ".gr-sec > .gr-demo, .gr-shell__main > section > *, .gr-kcol, .gr-product, .gr-quick__item, .gr-errtile, .gr-review, .gr-price, .gr-feature, .gr-stat";
    var rv = reduce ? [] : root.querySelectorAll(revealSel);
    rv.forEach(function (el) { if (el.closest(".gr-rv") && el.closest(".gr-rv") !== el) return; el.classList.add("gr-rv"); var i = Array.prototype.indexOf.call(el.parentNode.children, el); el.style.setProperty("--d", Math.min(i, 6) * 0.06 + "s"); });
    if (!reduce) watch.forEach(function (el) { if (el.matches(".gr-progress, .gr-ring")) el.classList.add("gr-wait"); });
    var onIn = function (el) {
      el.classList.add("is-in"); el.classList.remove("gr-wait");
      if (el.matches(".gr-stat__value, .gr-price__amount, .gr-rsum__score > b")) countUp(el);
      if (el.matches(".gr-ring")) { var b = el.querySelector("b"); if (b) countUp(b); }
    };
    if ("IntersectionObserver" in window && !reduce) {
      var io = new IntersectionObserver(function (es) { es.forEach(function (e) { if (e.isIntersecting) { onIn(e.target); io.unobserve(e.target); } }); }, { threshold: 0.15 });
      watch.forEach(function (el) { io.observe(el); }); rv.forEach(function (el) { io.observe(el); });
    } else { watch.forEach(onIn); rv.forEach(function (el) { el.classList.add("is-in"); }); }
    // ripple
    root.addEventListener("pointerdown", function (e) {
      var b = e.target.closest(".gr-btn, .gr-fab, .gr-iconbtn, .gr-quick__item, .gr-paymethod"); if (!b || reduce || b.disabled) return;
      var r = b.getBoundingClientRect(), d = Math.max(r.width, r.height) * 2.2, s = document.createElement("span");
      s.className = "gr-ripple"; s.style.width = s.style.height = d + "px"; s.style.left = (e.clientX - r.left - d / 2) + "px"; s.style.top = (e.clientY - r.top - d / 2) + "px";
      b.appendChild(s); setTimeout(function () { s.remove(); }, 650);
    });
    // dropdowns
    root.querySelectorAll("[data-gr-dropdown]").forEach(function (btn) {
      var dd = btn.closest(".gr-dropdown");
      btn.addEventListener("click", function (e) { e.stopPropagation(); var open = !dd.classList.contains("is-open");
        document.querySelectorAll(".gr-dropdown.is-open").forEach(function (o) { o.classList.remove("is-open"); });
        dd.classList.toggle("is-open", open); btn.setAttribute("aria-expanded", open ? "true" : "false"); });
      dd.querySelectorAll(".gr-menu__item").forEach(function (it) { it.addEventListener("click", function () {
        if (dd.hasAttribute("data-select")) { dd.querySelectorAll(".gr-menu__item").forEach(function (x) { x.classList.toggle("is-active", x === it); }); var l = dd.querySelector("[data-label]"); if (l) l.textContent = it.textContent.trim(); }
        dd.classList.remove("is-open"); btn.setAttribute("aria-expanded", "false"); }); });
    });
    if (!document._grDocBound) { document._grDocBound = true;
      document.addEventListener("click", function () { document.querySelectorAll(".gr-dropdown.is-open").forEach(function (o) { o.classList.remove("is-open"); }); });
      document.addEventListener("keydown", function (e) { if (e.key === "Escape") { document.querySelectorAll(".gr-dropdown.is-open, .gr-modal-live.is-open").forEach(function (o) { o.classList.remove("is-open"); }); } });
    }
    // tabs switch
    root.querySelectorAll(".gr-tabs").forEach(function (tabs) {
      tabs.addEventListener("click", function (e) { var t = e.target.closest(".gr-tab"); if (!t || !tabs.contains(t)) return; e.preventDefault();
        tabs.querySelectorAll(".gr-tab").forEach(function (x) { x.classList.toggle("is-active", x === t); }); });
    });
    // toasts
    root.querySelectorAll("[data-gr-toast]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var st = document.querySelector(".gr-toaststack"); if (!st) { st = document.createElement("div"); st.className = "gr-toaststack gr"; document.body.appendChild(st); }
        var t = document.createElement("div"); t.className = "gr-toast"; t.setAttribute("role", "status");
        t.innerHTML = '<span class="gr-toast__icon">' + icon("check") + "</span>" + btn.getAttribute("data-gr-toast"); st.appendChild(t);
        setTimeout(function () { t.classList.add("is-leaving"); setTimeout(function () { t.remove(); }, 380); }, 3200);
      });
    });
    // live modal
    root.querySelectorAll("[data-gr-modal]").forEach(function (btn) {
      btn.addEventListener("click", function () { var m = document.getElementById(btn.getAttribute("data-gr-modal")); if (m) m.classList.add("is-open"); });
    });
    root.querySelectorAll(".gr-modal-live").forEach(function (m) {
      m.addEventListener("click", function (e) { if (e.target === m || e.target.closest("[data-gr-close]")) m.classList.remove("is-open"); });
    });
    // replay
    root.querySelectorAll("[data-gr-replay]").forEach(function (btn) {
      btn.addEventListener("click", function () { var scope = document.getElementById(btn.getAttribute("data-gr-replay")); if (!scope) return;
        scope.querySelectorAll(".gr-progress, .gr-ring").forEach(function (el) { el.classList.add("gr-wait"); el.classList.remove("is-in"); });
        scope.querySelectorAll(".gr-ring b, .gr-stat__value").forEach(function (el) { el._counted = false; });
        void scope.offsetWidth; setTimeout(function () { scope.querySelectorAll(".gr-progress, .gr-ring, .gr-stat__value").forEach(onIn); }, 60); });
    });
    root.querySelectorAll("[data-gr-seg]").forEach(function (seg) {
      seg.addEventListener("click", function (e) {
        var b = e.target.closest("button"); if (!b) return;
        seg.querySelectorAll("button").forEach(function (x) { x.setAttribute("aria-pressed", x === b ? "true" : "false"); });
        if (seg.hasAttribute("data-theme-toggle")) document.documentElement.setAttribute("data-theme", b.getAttribute("data-value"));
      });
    });
  }
  window.Gooseroot = { icon: icon, logo: logo, lens: lens, mount: mount, icons: Object.keys(ICONS) };
})();
