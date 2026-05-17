const fs = require("fs");
const path = require("path");
const { pathToFileURL } = require("url");
const { chromium, webkit } = require("@playwright/test");

const root = path.resolve(__dirname, "..");
const htmlDirectory = path.join(root, "tmp", "rendered");
const screenshotDirectory = path.join(root, "tmp", "screenshots");
const fontDirectory = path.join(__dirname, "Fonts");
const highlightScript = path.join(
    root,
    "MarkdownPipeline",
    "Sources",
    "MarkdownPipeline",
    "Resources",
    "WebResources",
    "highlight.min.js"
);

const presets = {
    "mac-preview": { width: 1000, minimumHeight: 760 },
    narrow: { width: 720, minimumHeight: 760 }
};
const colorSchemes = ["light", "dark"];
const deviceScaleFactor = 2;
const defaultBrowserName = process.platform === "darwin" ? "webkit" : "chromium";
const browserName = process.env.RENDER_FIXTURES_BROWSER ?? defaultBrowserName;

function browserType() {
    switch (browserName) {
    case "chromium":
        return chromium;
    case "webkit":
        return webkit;
    default:
        throw new Error(`Unsupported RENDER_FIXTURES_BROWSER "${browserName}". Use "chromium" or "webkit".`);
    }
}

function findFont(patterns) {
    if (!fs.existsSync(fontDirectory)) {
        return null;
    }

    const files = fs.readdirSync(fontDirectory)
        .filter(fileName => /\.(otf|ttf|woff2?|ttc)$/i.test(fileName));

    for (const pattern of patterns) {
        const match = files.find(fileName => pattern.test(fileName));
        if (match) {
            return path.join(fontDirectory, match);
        }
    }

    return null;
}

function localFontCSS() {
    const systemRegular = findFont([
        /SF[- ]?Pro.*Text.*Regular/i,
        /SF[- ]?Pro.*Regular/i,
        /SFNS.*Regular/i
    ]);
    const systemSemibold = findFont([
        /SF[- ]?Pro.*Text.*Semi.?Bold/i,
        /SF[- ]?Pro.*Semi.?Bold/i,
        /SFNS.*Bold/i
    ]);
    const monoRegular = findFont([
        /SF[- ]?Mono.*Regular/i,
        /SFMono.*Regular/i
    ]);
    const monoSemibold = findFont([
        /SF[- ]?Mono.*Semi.?Bold/i,
        /SFMono.*Semi.?Bold/i,
        /SF[- ]?Mono.*Bold/i,
        /SFMono.*Bold/i
    ]);

    const rules = [];
    if (systemRegular) {
        rules.push(`
            @font-face {
                font-family: "ScreenshotSystem";
                src: url("${pathToFileURL(systemRegular).href}");
                font-weight: 400;
            }
        `);
    }
    if (systemSemibold) {
        rules.push(`
            @font-face {
                font-family: "ScreenshotSystem";
                src: url("${pathToFileURL(systemSemibold).href}");
                font-weight: 600 700;
            }
        `);
    }
    if (monoRegular) {
        rules.push(`
            @font-face {
                font-family: "ScreenshotMono";
                src: url("${pathToFileURL(monoRegular).href}");
                font-weight: 400;
            }
        `);
    }
    if (monoSemibold) {
        rules.push(`
            @font-face {
                font-family: "ScreenshotMono";
                src: url("${pathToFileURL(monoSemibold).href}");
                font-weight: 600 700;
            }
        `);
    }

    if (systemRegular) {
        rules.push(`
            body {
                font-family: "ScreenshotSystem", system-ui, sans-serif !important;
            }
        `);
    }
    if (monoRegular) {
        rules.push(`
            pre,
            code {
                font-family: "ScreenshotMono", "SF Mono", monospace !important;
            }
        `);
    }

    if (process.env.RENDER_FIXTURES_DEBUG_FONTS === "1") {
        console.log("Screenshot font override:");
        console.log(`  system regular: ${systemRegular ?? "(not found)"}`);
        console.log(`  system semibold: ${systemSemibold ?? "(not found)"}`);
        console.log(`  mono regular: ${monoRegular ?? "(not found)"}`);
        console.log(`  mono semibold: ${monoSemibold ?? "(not found)"}`);
    }

    return rules.join("\n");
}

function renderedHTMLFiles() {
    return fs.readdirSync(htmlDirectory)
        .filter(fileName => fileName.endsWith(".html"))
        .sort()
        .map(fileName => path.join(htmlDirectory, fileName));
}

async function applyBrowserOnlyEnhancements(page) {
    const fontCSS = localFontCSS();
    if (fontCSS.length > 0) {
        await page.addStyleTag({ content: fontCSS });
    }

    await page.addScriptTag({ path: highlightScript });
    await page.evaluate(() => {
        document.querySelectorAll("pre > code").forEach(code => {
            if (!code.classList.contains("hljs")) {
                window.hljs.highlightElement(code);
            }
        });
    });
}

(async () => {
    fs.mkdirSync(screenshotDirectory, { recursive: true });

    const htmlFiles = renderedHTMLFiles();
    if (htmlFiles.length === 0) {
        throw new Error(`No rendered HTML files found in ${htmlDirectory}`);
    }

    const browser = await browserType().launch({ headless: true });

    for (const htmlPath of htmlFiles) {
        const baseName = path.basename(htmlPath, ".html");
        for (const [presetName, preset] of Object.entries(presets)) {
            for (const colorScheme of colorSchemes) {
                const page = await browser.newPage({
                    viewport: { width: preset.width, height: preset.minimumHeight },
                    deviceScaleFactor,
                    colorScheme
                });

                await page.goto(pathToFileURL(htmlPath).href);
                await applyBrowserOnlyEnhancements(page);

                const outputPath = path.join(screenshotDirectory, `${baseName}-${presetName}-${colorScheme}.png`);
                await page.screenshot({ path: outputPath, fullPage: true });
                await page.close();

                console.log(path.relative(root, outputPath));
            }
        }
    }

    await browser.close();
})().catch(error => {
    console.error(error);
    process.exit(1);
});
