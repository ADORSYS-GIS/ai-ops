/**
 * scripts/agentic_reviewer.js
 * 
 * THE BRAIN: Consolidates PR analysis, Gemini reasoning, and Playwright execution.
 * Highly visual, evidence-based agentic review.
 */
'use strict';

const { Octokit } = require('@octokit/rest');
const { chromium } = require('playwright');
const OpenAI = require('openai');
const fs = require('fs');
const path = require('path');

// ── Configuration ────────────────────────────────────────────────────────────
const GITHUB_TOKEN = process.env.PAT_TOKEN || process.env.GITHUB_TOKEN;
const PR_NUMBER = parseInt(process.env.PR_NUMBER, 10);
const [OWNER, REPO] = (process.env.GITHUB_REPOSITORY || '').split('/');
const APP_BASE_URL = (process.env.APP_BASE_URL || '').replace(/\/$/, '');
const ARTIFACTS_DIR = process.env.ARTIFACTS_DIR || path.join(__dirname, '../agent-artifacts');

const llmClient = new OpenAI({
    apiKey: process.env.LLM_API_KEY,
    baseURL: process.env.LLM_BASE_URL || 'https://api.ai.camer.digital/v1',
});

const TEXT_MODEL = process.env.LLM_MODEL || 'gemini-2.5-flash';
const VISION_MODEL = process.env.LLM_VL_MODEL || 'gemini-2.5-flash';

// ── GitHub Helpers ───────────────────────────────────────────────────────────
const octokit = new Octokit({ auth: GITHUB_TOKEN });

async function postProgress(text) {
    const body = `## 🤖 Agentic Reviewer — In Progress\n\n${text}\n\n⏱️ _${new Date().toUTCString()}_`;
    console.log(`[PROGRESS] ${text}`);
    // If we have a stored comment ID, we could update it. For simplicity, we just log.
}

// ── Playwright Agent ────────────────────────────────────────────────────────
async function runTest(scenario, baseUrl) {
    console.log(`\n🎭 Running: ${scenario.title}`);
    const browser = await chromium.launch();
    const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
    const page = await context.newPage();

    const evidence = { screenshots: [], consoleLogs: [], status: 'passed', error: null };

    page.on('console', msg => evidence.consoleLogs.push(msg.text()));

    try {
        const fullUrl = (scenario.url.startsWith('http') || scenario.url.startsWith('file://'))
            ? scenario.url
            : `${baseUrl}${scenario.url}`;

        console.log(`   🔗 Navigating to: ${fullUrl}`);
        await page.goto(fullUrl, { waitUntil: 'networkidle' });

        // Initial screenshot
        const initialSS = path.resolve(ARTIFACTS_DIR, `ss_${scenario.id}_init.png`);
        await page.screenshot({ path: initialSS });
        evidence.screenshots.push(initialSS);

        // Execute steps
        for (let i = 0; i < scenario.steps.length; i++) {
            const step = scenario.steps[i];
            if (typeof step === 'string') {
                console.log(`   - Step: ${step}`);
                await page.waitForTimeout(1000);
            } else {
                console.log(`   - Action: ${JSON.stringify(step)}`);
                if (step.action === 'fill') {
                    await page.fill(step.selector, step.value);
                } else if (step.action === 'click') {
                    await page.click(step.selector);
                } else if (step.action === 'wait') {
                    await page.waitForTimeout(step.ms || 1000);
                }
            }

            // Take screenshot after each complex action to provide visual trace
            const stepSS = path.resolve(ARTIFACTS_DIR, `ss_${scenario.id}_step_${i}.png`);
            await page.screenshot({ path: stepSS });
            evidence.screenshots.push(stepSS);
        }
    } catch (err) {
        console.error(`   ❌ Scenario ${scenario.id} failed:`, err.message);
        evidence.status = 'failed';
        evidence.error = err.message;
    }

    await browser.close();
    return evidence;
}

// ── Business Logic ───────────────────────────────────────────────────────────
async function main() {
    if (!PR_NUMBER || !OWNER || !REPO) {
        console.error('❌ Missing core env vars (PR_NUMBER, GITHUB_REPOSITORY)');
        process.exit(1);
    }
    fs.mkdirSync(ARTIFACTS_DIR, { recursive: true });

    try {
        // 1. Fetch PR Data
        await postProgress('> 📥 Fetching PR content...');
        const { data: pr } = await octokit.pulls.get({ owner: OWNER, repo: REPO, pull_number: PR_NUMBER });
        const { data: diff } = await octokit.request('GET /repos/{owner}/{repo}/pulls/{pull_number}', {
            owner: OWNER, repo: REPO, pull_number: PR_NUMBER,
            headers: { accept: 'application/vnd.github.v3.diff' },
        });

        // 2. Generate Testing Plan
        await postProgress('> 🧠 Gemini is reasoning about your code changes...');
        const planPrompt = `PR: ${pr.title}\nDIFF:\n${diff.slice(0, 10000)}\n\n
        Act as a Senior QA. Output ONLY a JSON array of up to 3 specific test scenarios (id, title, url, steps[]).
        
        CRITICAL: 
        1. Always include one "Full System Walkthrough" scenario that covers the entire 'Golden Path': 
           Login -> View Product -> Add to Cart -> Checkout -> Success.
        2. Other scenarios should focus specifically on the PR diff changes.
        
        Selectors available:
        - Login: #username, #password, #login-btn
        - Products: #product-helmet, #product-boots, #buy-btn, #checkout-btn
        - Navbar: #cart-count, #last-login-time
        - Checkout: #promo-code, #promo-apply, #card-num, #pay-btn
        
        Step format:
        - "description string"
        - { "action": "fill", "selector": "#username", "value": "tester" }
        - { "action": "click", "selector": "#login-btn" }
        - { "action": "wait", "ms": 2000 }
        
        Each action triggers a screenshot. Generate high-depth scenarios.`;
        const planResp = await llmClient.chat.completions.create({
            model: TEXT_MODEL,
            messages: [{ role: 'user', content: planPrompt }],
            temperature: 0.1,
        });

        let scenarios = [];
        try {
            scenarios = JSON.parse(planResp.choices[0].message.content.replace(/```json|```/g, ''));
        } catch (e) {
            console.error('Plan parsing failed. Using default.');
            scenarios = [{ id: 'TC-1', title: 'Main Page Integrity', url: '/', steps: ['Check if marketplace loads'] }];
        }

        // 3. Run Tests
        const results = [];
        const isLocalFile = !APP_BASE_URL;
        const testUrlBase = APP_BASE_URL || `file://${path.resolve(process.cwd(), 'index.html')}`;

        console.log(`\n🌐 Testing Target Base: ${testUrlBase}`);
        if (isLocalFile) console.log('   (Local file mode: Sub-paths will be handled as the same local file)');

        for (const scenario of scenarios) {
            await postProgress(`> 🎭 Executing agentic test: ${scenario.title}`);

            // For local files, we just use the base file URL (no sub-paths)
            const scenarioUrl = (isLocalFile || !scenario.url) ? testUrlBase : (scenario.url.startsWith('http') ? scenario.url : `${testUrlBase}${scenario.url}`);

            const result = await runTest({ ...scenario, url: scenarioUrl }, testUrlBase);
            results.push({ ...scenario, ...result });

            if (result.screenshots.length > 0) {
                console.log(`   📸 Screenshot captured!`);
            }
        }

        // 4. Final Review
        await postProgress('> 🖊️ Synthesizing results into a final review...');
        const finalPrompt = `PR: ${pr.title}\nDIFF: ${diff.slice(0, 6000)}\nTESTS: ${JSON.stringify(results)}\n\nWrite a high-impact, evidence-based PR review in Markdown. Include clear sections: Summary, UI Evidence, and Verdict (APPROVE/REQUEST_CHANGES). Mention specific lines in the diff and specific observations from the tests.`;
        const finalResp = await llmClient.chat.completions.create({
            model: TEXT_MODEL,
            messages: [{ role: 'user', content: finalPrompt }],
            temperature: 0.3,
        });

        // 5. Post to GitHub
        const finalBody = `## 🤖 Agentic Reviewer — Analysis Complete\n\n${finalResp.choices[0].message.content}\n\n---\n_Reviewers note: This analysis was generated by a Gemini-powered autonomous agent using Playwright._`;

        let reviewEvent = results.some(r => r.status === 'failed') ? 'REQUEST_CHANGES' : 'APPROVE';

        console.log(`\n📤 Posting review [${reviewEvent}] to PR #${PR_NUMBER}...`);

        try {
            await octokit.pulls.createReview({
                owner: OWNER,
                repo: REPO,
                pull_number: PR_NUMBER,
                body: finalBody,
                event: reviewEvent,
            });
        } catch (err) {
            console.error(`⚠️  Direct review [${reviewEvent}] failed (may be self-review or permission issue). Falling back to generic COMMENT.`);
            if (err.response && err.response.data) {
                console.error('   GitHub Error Detail:', JSON.stringify(err.response.data.errors, null, 2));
            }
            await octokit.pulls.createReview({
                owner: OWNER,
                repo: REPO,
                pull_number: PR_NUMBER,
                body: finalBody,
                event: 'COMMENT',
            });
        }

        console.log('\n✅ Mission Accomplished.');
    } catch (err) {
        console.error('💥 Critical Agent Failure:', err);
        if (err.response && err.response.data) console.error('   Error Data:', err.response.data);
        process.exit(1);
    }
}

main();
