#!/usr/bin/env bun

import { cdpEval, cdpCommand } from './lib/cdp';
import { findCoords } from './lib/vision';
import { spawnSync } from 'child_process';

const [cmd, ...args] = Bun.argv.slice(2);

const commands: Record<string, (args: string[]) => Promise<void>> = {
  async eval(args) {
    const [js] = args;
    if (!js) throw new Error('usage: br eval <js-code>');
    const result = await cdpEval(js);
    if (result !== undefined) {
      console.log(typeof result === 'object' ? JSON.stringify(result, null, 2) : result);
    }
  },

  async new_tab(args) {
    const [url] = args;
    if (!url) throw new Error('usage: br new_tab <url>');
    await cdpCommand('Target.createTarget', { url });
    console.log(`new tab: ${url}`);
  },

  async new_window(args) {
    const [url] = args;
    if (!url) throw new Error('usage: br new_window <url>');
    await cdpCommand('Target.createTarget', { url, newWindow: true, background: false });
    console.log(`new window: ${url}`);
  },

  async screenshot(args) {
    const [name] = args;
    if (!name) throw new Error('usage: br screenshot <name>');
    
    const result = await cdpCommand('Page.captureScreenshot', { format: 'png' }) as any;
    const buffer = Buffer.from(result.data, 'base64');
    const path = `/tmp/br_${name}.png`;
    await Bun.write(path, buffer);
    console.log(path);
  },

  async point(args) {
    const [name, prompt] = args;
    if (!name || !prompt) throw new Error('usage: br point <screenshot-name> <prompt>');
    
    const imagePath = `/tmp/br_${name}.png`;
    const coords = await findCoords(imagePath, prompt);
    console.log(`${coords.x},${coords.y}`);
  },

  async click(args) {
    const [name, prompt] = args;
    if (!name || !prompt) throw new Error('usage: br click <screenshot-name> <prompt>');
    
    const imagePath = `/tmp/br_${name}.png`;
    const { x, y } = await findCoords(imagePath, prompt);
    
    const result = await cdpEval(`
      let el = document.elementFromPoint(${x}, ${y});
      if (el) {
        let clickTarget = el.closest('a') || el.querySelector('a') || el;
        clickTarget.click();
        'clicked at ${x},${y}: ' + clickTarget.tagName + (clickTarget.href ? ' -> ' + clickTarget.href : '');
      } else {
        'no element at ${x},${y}';
      }
    `);
    console.log(result);
  },

  async click_in_new_tab(args) {
    const [name, prompt] = args;
    if (!name || !prompt) throw new Error('usage: br click_in_new_tab <screenshot-name> <prompt>');
    
    const imagePath = `/tmp/br_${name}.png`;
    const { x, y } = await findCoords(imagePath, prompt);
    
    const href = await cdpEval(`
      let el = document.elementFromPoint(${x}, ${y});
      if (el) {
        let target = el.closest('a') || el.querySelector('a');
        if (target && target.href) {
          target.href;
        } else {
          null;
        }
      } else {
        null;
      }
    `);
    
    if (!href) {
      console.log(`no link found at ${x},${y}`);
      return;
    }
    
    await cdpCommand('Target.createTarget', { url: href as string });
    console.log(`opened in new tab: ${href}`);
  },

  async focus() {
    spawnSync('osascript', ['-e', 'tell application "Brave Browser" to activate'], {
      stdio: 'inherit'
    });
  }
};

if (!cmd || !commands[cmd]) {
  console.error('usage: br <command> [args...]');
  console.error('\ncommands:');
  console.error('  eval <js-code>                      execute JS in active tab');
  console.error('  new_tab <url>                       open new tab');
  console.error('  new_window <url>                    open new window');
  console.error('  screenshot <name>                   save screenshot as /tmp/br_<name>.png');
  console.error('  point <screenshot-name> <prompt>    find coords in screenshot');
  console.error('  click <screenshot-name> <prompt>    find and click element');
  console.error('  click_in_new_tab <name> <prompt>    find and open link in new tab');
  console.error('  focus                               bring browser to foreground');
  process.exit(1);
}

try {
  await commands[cmd](args);
} catch (error: any) {
  console.error('error:', error.message);
  process.exit(1);
}

