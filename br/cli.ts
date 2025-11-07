#!/usr/bin/env bun

import { cdp_eval, cdp_cmd } from './cdp';
import { find_coords, img_path, js_snippets } from './vision';
import { spawnSync } from 'child_process';

const [cmd, ...args] = Bun.argv.slice(2);

type Cmd = (args: string[]) => Promise<void>;

const require_args = (args: string[], count: number, usage: string) => {
  if (args.length < count) throw new Error(`usage: ${usage}`);
};

const commands: Record<string, Cmd> = {
  async eval(args) {
    require_args(args, 1, 'br eval <js-code>');
    const result = await cdp_eval(args.join(' '));
    if (result !== undefined) {
      console.log(typeof result === 'object' ? JSON.stringify(result, null, 2) : result);
    }
  },

  async new_tab(args) {
    require_args(args, 1, 'br new_tab <url>');
    await cdp_cmd('Target.createTarget', { url: args[0] });
    console.log(`new tab: ${args[0]}`);
  },

  async new_window(args) {
    require_args(args, 1, 'br new_window <url>');
    await cdp_cmd('Target.createTarget', { url: args[0], newWindow: true, background: false });
    console.log(`new window: ${args[0]}`);
  },

  async screenshot(args) {
    require_args(args, 1, 'br screenshot <name>');
    const result = await cdp_cmd('Page.captureScreenshot', { format: 'png' }) as any;
    const buffer = Buffer.from(result.data, 'base64');
    const path = img_path(args[0]);
    await Bun.write(path, buffer);
    console.log(path);
  },

  async point(args) {
    require_args(args, 2, 'br point <screenshot-name> <prompt>');
    const [name, ...promptParts] = args;
    const coords = await find_coords(img_path(name), promptParts.join(' '));
    console.log(`${coords.x},${coords.y}`);
  },

  async click(args) {
    require_args(args, 2, 'br click <screenshot-name> <prompt>');
    const [name, ...promptParts] = args;
    const { x, y } = await find_coords(img_path(name), promptParts.join(' '));
    const result = await cdp_eval(js_snippets.click_at(x, y));
    console.log(result);
  },

  async click_in_new_tab(args) {
    require_args(args, 2, 'br click_in_new_tab <screenshot-name> <prompt>');
    const [name, ...promptParts] = args;
    const { x, y } = await find_coords(img_path(name), promptParts.join(' '));
    const href = await cdp_eval(js_snippets.get_href(x, y));
    
    if (!href) {
      console.log(`no link found at ${x},${y}`);
      return;
    }
    
    await cdp_cmd('Target.createTarget', { url: href as string });
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