#!/usr/bin/env bun

import { cdp_eval, cdp_cmd, list_targets } from './cdp';
import { find_coords, img_path, js_snippets } from './vision';
import { $ } from 'bun';

const [cmd, ...args] = Bun.argv.slice(2);

type Cmd = (args: string[]) => Promise<void>;

const require_args = (args: string[], count: number, usage: string) => {
  if (args.length < count) throw new Error(`usage: ${usage}`);
};

const split_prompt_args = (args: string[], beforePrompt: number): [string[], string] => {
  const before = args.slice(0, beforePrompt);
  const prompt = args.slice(beforePrompt).join(' ');
  if (!prompt) throw new Error('prompt required');
  return [before, prompt];
};

async function dispatch_mouse(type: 'mousePressed' | 'mouseReleased', x: number, y: number, targetId: string) {
  await cdp_cmd('Input.dispatchMouseEvent', { type, x, y, button: 'middle', clickCount: 1 }, targetId);
}

async function wait_for_new_tab(idsBefore: Set<string>, maxAttempts = 10): Promise<string | null> {
  for (let i = 0; i < maxAttempts; i++) {
    await new Promise(resolve => setTimeout(resolve, 300));
    const targetsAfter = await list_targets();
    const newTabs = targetsAfter.filter((t: any) => t.type === 'page' && !idsBefore.has(t.id));
    if (newTabs.length > 0) return newTabs[0].id;
  }
  return null;
}

const commands: Record<string, Cmd> = {
  async list_windows() {
    const targets = await list_targets();
    const pages = targets.filter((t: any) => t.type === 'page');
    
    const windowMap = new Map<string, any[]>();
    const rootWindows = new Set<string>();
    
    for (const page of pages) {
      if (!page.openerId) {
        rootWindows.add(page.id);
        if (!windowMap.has(page.id)) windowMap.set(page.id, []);
      }
    }
    
    for (const page of pages) {
      if (page.openerId && rootWindows.has(page.openerId)) {
        if (!windowMap.has(page.openerId)) windowMap.set(page.openerId, []);
        windowMap.get(page.openerId)!.push(page);
      }
    }
    
    Array.from(rootWindows).forEach(id => {
      const rootPage = pages.find((p: any) => p.id === id);
      const tabs = windowMap.get(id) || [];
      console.log(`${id}|${rootPage?.title || rootPage?.url || 'untitled'}|${tabs.length + 1}`);
    });
  },

  async list_tabs(args) {
    require_args(args, 1, 'br list_tabs "window-id"');
    const [targetId] = args;
    const targets = await list_targets();
    const pages = targets.filter((t: any) => t.type === 'page');
    pages.filter((t: any) => t.id === targetId || t.openerId === targetId)
      .forEach((t: any) => console.log(`${t.id}|${t.title}`));
  },

  async new_window(args) {
    require_args(args, 1, 'br new_window "url"');
    const result = await cdp_cmd('Target.createTarget', { 
      url: args[0], 
      newWindow: true, 
      background: false 
    }) as any;
    console.log(result.targetId);
  },

  async new_tab(args) {
    require_args(args, 2, 'br new_tab "tab-id" "url"');
    const [targetId, url] = args;
    
    const coords = await cdp_eval(`
      (() => {
        const link = document.querySelector('a[href]');
        if (!link) return null;
        const rect = link.getBoundingClientRect();
        return { x: rect.left + rect.width/2, y: rect.top + rect.height/2 };
      })()
    `, targetId) as any;
    
    if (!coords) throw new Error('no clickable links found on page');
    
    const targetsBefore = await list_targets();
    const idsBefore: Set<string> = new Set(targetsBefore.map((t: any) => t.id as string));
    
    await dispatch_mouse('mousePressed', coords.x, coords.y, targetId);
    await dispatch_mouse('mouseReleased', coords.x, coords.y, targetId);
    
    const newTabId = await wait_for_new_tab(idsBefore);
    
    if (newTabId) {
      await new Promise(resolve => setTimeout(resolve, 500));
      await cdp_cmd('Page.navigate', { url }, newTabId);
      console.log(newTabId);
    } else {
      console.log('tab created but id unknown');
    }
  },

  async goto(args) {
    require_args(args, 2, 'br goto "tab-id" "url"');
    const [targetId, url] = args;
    await cdp_cmd('Page.navigate', { url }, targetId);
    console.log(`navigated to: ${url}`);
  },

  async screenshot(args) {
    require_args(args, 2, 'br screenshot "tab-id" "name"');
    const [targetId, name] = args;
    const result = await cdp_cmd('Page.captureScreenshot', { format: 'png' }, targetId) as any;
    const buffer = Buffer.from(result.data, 'base64');
    const path = img_path(name);
    await Bun.write(path, buffer);
    console.log(path);
  },

  async point(args) {
    require_args(args, 3, 'br point "tab-id" "name" "prompt"');
    const [[targetId, name], prompt] = split_prompt_args(args, 2);
    const coords = await find_coords(img_path(name), prompt, targetId);
    console.log(`${coords.x},${coords.y}`);
  },

  async click(args) {
    require_args(args, 3, 'br click "tab-id" "name" "prompt"');
    const [[targetId, name], prompt] = split_prompt_args(args, 2);
    const { x, y } = await find_coords(img_path(name), prompt, targetId);
    const result = await cdp_eval(js_snippets.click_at(x, y), targetId);
    console.log(result);
  },

  async click_in_new_tab(args) {
    require_args(args, 3, 'br click_in_new_tab "tab-id" "name" "prompt"');
    const [[targetId, name], prompt] = split_prompt_args(args, 2);
    const { x, y } = await find_coords(img_path(name), prompt, targetId);
    
    const targetsBefore = await list_targets();
    const idsBefore: Set<string> = new Set(targetsBefore.map((t: any) => t.id as string));
    
    await dispatch_mouse('mousePressed', x, y, targetId);
    await dispatch_mouse('mouseReleased', x, y, targetId);
    
    const newTabId = await wait_for_new_tab(idsBefore);
    console.log(newTabId || 'tab created but id unknown');
  },

  async eval(args) {
    require_args(args, 2, 'br eval "tab-id" "js-code"');
    const [targetId, ...jsParts] = args;
    const result = await cdp_eval(jsParts.join(' '), targetId);
    if (result !== undefined) {
      console.log(typeof result === 'object' ? JSON.stringify(result, null, 2) : result);
    }
  },

  async screenshot_screen(args) {
    require_args(args, 1, 'br screenshot_screen "name"');
    const [name] = args;
    const path = img_path(name);
    await $`screencapture -x ${path}`;
    console.log(path);
  },

  async point_screen(args) {
    require_args(args, 2, 'br point_screen "name" "prompt"');
    const [[name], prompt] = split_prompt_args(args, 1);

    const imgPath = img_path(name);
    const imgSize = await $`sips -g pixelWidth -g pixelHeight ${imgPath}`.text();
    const imgWidth = parseInt(imgSize.match(/pixelWidth: (\d+)/)?.[1] || '0');
    const imgHeight = parseInt(imgSize.match(/pixelHeight: (\d+)/)?.[1] || '0');

    const boundsStr = await $`osascript -e 'tell application "Finder" to get bounds of window of desktop'`.text();
    const bounds = boundsStr.trim().split(', ').map(Number);
    const logicalWidth = bounds[2];
    const logicalHeight = bounds[3];

    const scaleX = logicalWidth / imgWidth;
    const scaleY = logicalHeight / imgHeight;

    const coords = await find_coords(imgPath, prompt);
    const logicalX = Math.round(coords.x * scaleX);
    const logicalY = Math.round(coords.y * scaleY);

    console.log(`${logicalX},${logicalY}`);
  },

  async click_screen(args) {
    require_args(args, 1, 'br click_screen "x,y"');
    const [coords] = args;
    const [x, y] = coords.split(',').map(Number);
    const script = `tell application "System Events" to click at {${x}, ${y}}`;
    await $`osascript -e ${script}`;
    console.log(`clicked at ${x},${y}`);
  },

  async type_screen(args) {
    require_args(args, 1, 'br type_screen "text"');
    const text = args.join(' ');
    const script = `tell application "System Events" to keystroke "${text}"`;
    await $`osascript -e ${script}`;
    console.log(`typed: ${text}`);
  },

  async key_screen(args) {
    require_args(args, 1, 'br key_screen "key"');
    const [key] = args;
    const keyMap: Record<string, string> = {
      enter: '36',
      return: '36',
      tab: '48',
      escape: '53',
      space: '49',
      delete: '51',
      cmd: '55',
      command: '55',
    };
    const keyCode = keyMap[key.toLowerCase()] || key;
    const script = `tell application "System Events" to key code ${keyCode}`;
    await $`osascript -e ${script}`;
    console.log(`pressed: ${key}`);
  }
};

if (!cmd || !commands[cmd]) {
  console.log(`
┌────────────────────────────────────────────────────┐
│ br — browser automation via CDP + moondream vision │
└────────────────────────────────────────────────────┘

window management
  list_windows                         list root windows
  list_tabs "window-id"                list tabs in window
  new_window "url"                     create window → tab-id
  new_tab "tab-id" "url"               create tab in window → tab-id

navigation
  goto "tab-id" "url"                  navigate to url
  eval "tab-id" "js-code"              execute javascript

vision + interaction (CDP)
  screenshot "tab-id" "name"           save → /tmp/br_name.png
  point "tab-id" "name" "prompt"       moondream → x,y coords
  click "tab-id" "name" "prompt"       vision → click element
  click_in_new_tab "tab-id" "name" "p" vision → click → new tab

OS-level automation
  screenshot_screen "name"             capture screen → /tmp/br_name.png
  point_screen "name" "prompt"         moondream on screen → x,y coords
  click_screen "x,y"                   OS-level click at coords
  type_screen "text"                   keyboard input
  key_screen "key"                     press specific key (enter, tab, etc)
`);
  process.exit(1);
}

try {
  await commands[cmd](args);
} catch (error: any) {
  console.error('error:', error.message);
  process.exit(1);
}
