#!/usr/bin/env bun

import { cdpEval, cdpCommand, listTargets, getTarget } from './lib/cdp';
import { findCoords } from './lib/vision';

const [cmd, ...args] = Bun.argv.slice(2);

const commands: Record<string, (args: string[]) => Promise<void>> = {
  async list_windows() {
    const targets = await listTargets();
    const pages = targets.filter((t: any) => t.type === 'page');
    
    const windowMap = new Map<string, any[]>();
    const rootWindows = new Set<string>();
    
    for (const page of pages) {
      if (!page.openerId) {
        rootWindows.add(page.id);
        if (!windowMap.has(page.id)) {
          windowMap.set(page.id, []);
        }
      }
    }
    
    for (const page of pages) {
      if (page.openerId && rootWindows.has(page.openerId)) {
        if (!windowMap.has(page.openerId)) {
          windowMap.set(page.openerId, []);
        }
        windowMap.get(page.openerId)!.push(page);
      }
    }
    
    const windows = Array.from(rootWindows).map(id => {
      const rootPage = pages.find((p: any) => p.id === id);
      const tabs = windowMap.get(id) || [];
      return [id, rootPage?.title || rootPage?.url || 'untitled', tabs.length + 1];
    });
    
    windows.forEach(w => {
      console.log(`${w[0]}|${w[1]}|${w[2]}`);
    });
  },

  async list_tabs(args) {
    const [targetId] = args;
    if (!targetId) throw new Error('usage: br list_tabs <target-id>');
    
    const targets = await listTargets();
    const pages = targets.filter((t: any) => t.type === 'page');
    
    const windowTabs = pages.filter((t: any) => 
      t.id === targetId || t.openerId === targetId
    );
    
    windowTabs.forEach((t: any) => {
      console.log(`${t.id}|${t.title}`);
    });
  },

  async new_window(args) {
    const [url] = args;
    if (!url) throw new Error('usage: br new_window <url>');
    const result = await cdpCommand('Target.createTarget', { url, newWindow: true, background: false }) as any;
    console.log(result.targetId);
  },

  async new_tab(args) {
    const [targetId, url] = args;
    if (!url) throw new Error('usage: br new_tab <target-id> <url>');
    const result = await cdpCommand('Target.createTarget', { url }, targetId) as any;
    console.log(result.targetId);
  },

  async goto(args) {
    const [targetId, url] = args;
    if (!targetId || !url) throw new Error('usage: br goto <target-id> <url>');
    await cdpCommand('Page.navigate', { url }, targetId);
    console.log(`navigated to: ${url}`);
  },

  async screenshot(args) {
    const [targetId, name] = args;
    if (!targetId || !name) throw new Error('usage: br screenshot <target-id> <name>');
    
    const result = await cdpCommand('Page.captureScreenshot', { format: 'png' }, targetId) as any;
    const buffer = Buffer.from(result.data, 'base64');
    const path = `/tmp/br_${name}.png`;
    await Bun.write(path, buffer);
    console.log(path);
  },

  async point(args) {
    const [targetId, name, ...promptParts] = args;
    if (!targetId || !name || promptParts.length === 0) {
      throw new Error('usage: br point <target-id> <screenshot-name> <prompt>');
    }
    
    const prompt = promptParts.join(' ');
    const imagePath = `/tmp/br_${name}.png`;
    const coords = await findCoords(imagePath, prompt, targetId);
    console.log(`${coords.x},${coords.y}`);
  },

  async click(args) {
    const [targetId, name, ...promptParts] = args;
    if (!targetId || !name || promptParts.length === 0) {
      throw new Error('usage: br click <target-id> <screenshot-name> <prompt>');
    }
    
    const prompt = promptParts.join(' ');
    const imagePath = `/tmp/br_${name}.png`;
    const { x, y } = await findCoords(imagePath, prompt, targetId);
    
    const result = await cdpEval(`
      let el = document.elementFromPoint(${x}, ${y});
      if (el) {
        let clickTarget = el.closest('a') || el.querySelector('a') || el;
        clickTarget.click();
        'clicked at ${x},${y}: ' + clickTarget.tagName + (clickTarget.href ? ' -> ' + clickTarget.href : '');
      } else {
        'no element at ${x},${y}';
      }
    `, targetId);
    console.log(result);
  },

  async click_in_new_tab(args) {
    const [targetId, name, ...promptParts] = args;
    if (!targetId || !name || promptParts.length === 0) {
      throw new Error('usage: br click_in_new_tab <target-id> <screenshot-name> <prompt>');
    }
    
    const prompt = promptParts.join(' ');
    const imagePath = `/tmp/br_${name}.png`;
    const { x, y } = await findCoords(imagePath, prompt, targetId);
    
    const targetsBefore = await listTargets();
    const idsBefore = new Set(targetsBefore.map((t: any) => t.id));
    
    await cdpCommand('Input.dispatchMouseEvent', {
      type: 'mousePressed',
      x,
      y,
      button: 'middle',
      clickCount: 1
    }, targetId);
    
    await cdpCommand('Input.dispatchMouseEvent', {
      type: 'mouseReleased',
      x,
      y,
      button: 'middle',
      clickCount: 1
    }, targetId);
    
    let newTab = null;
    for (let i = 0; i < 6; i++) {
      await new Promise(resolve => setTimeout(resolve, 500));
      const targetsAfter = await listTargets();
      const newTabs = targetsAfter.filter((t: any) => 
        t.type === 'page' && !idsBefore.has(t.id)
      );
      
      if (newTabs.length > 0) {
        newTab = newTabs[0];
        break;
      }
    }
    
    if (newTab) {
      console.log(newTab.id);
    } else {
      console.log('tab created but id unknown');
    }
  },

  async eval(args) {
    const [targetId, ...jsParts] = args;
    if (!targetId || jsParts.length === 0) throw new Error('usage: br eval <target-id> <js-code>');
    
    const js = jsParts.join(' ');
    const result = await cdpEval(js, targetId);
    if (result !== undefined) {
      console.log(typeof result === 'object' ? JSON.stringify(result, null, 2) : result);
    }
  }
};

if (!cmd || !commands[cmd]) {
  console.error('usage: br <command> [args...]');
  console.error('\ncommands:');
  console.error('  list_windows                        list windows: id|tabs|title');
  console.error('  list_tabs <target-id>               list tabs in window: id|url|title');
  console.error('  new_window <url>                    create window, returns target-id');
  console.error('  new_tab <target-id> <url>           create tab in window');
  console.error('  goto <target-id> <url>              navigate to url');
  console.error('  screenshot <target-id> <name>       save as /tmp/br_<name>.png');
  console.error('  point <target-id> <name> <prompt>   find coords via moondream');
  console.error('  click <target-id> <name> <prompt>   vision → click');
  console.error('  click_in_new_tab <id> <name> <p>    vision → new tab, returns target-id');
  console.error('  eval <target-id> <js-code>          execute CDP JS');
  process.exit(1);
}

try {
  await commands[cmd](args);
} catch (error: any) {
  console.error('error:', error.message);
  process.exit(1);
}
