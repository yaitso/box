import { vl } from 'moondream';
import { cdp_eval } from './cdp';

export const js_snippets = {
  viewport: 'JSON.stringify({ width: window.innerWidth, height: window.innerHeight })',
  
  element_at: (x: number, y: number) => `document.elementFromPoint(${x}, ${y})`,
  
  find_link: (x: number, y: number) => `
    (() => {
      let el = ${js_snippets.element_at(x, y)};
      return el ? (el.closest('a') || el.querySelector('a')) : null;
    })()
  `,
  
  click_at: (x: number, y: number) => `
    (() => {
      let el = ${js_snippets.element_at(x, y)};
      if (!el) return 'no element at ${x},${y}';
      let target = el.closest('a') || el.querySelector('a') || el;
      target.click();
      return 'clicked at ${x},${y}: ' + target.tagName + (target.href ? ' -> ' + target.href : '');
    })()
  `,
  
  get_href: (x: number, y: number) => `
    (() => {
      let el = ${js_snippets.element_at(x, y)};
      if (!el) return null;
      let link = el.closest('a') || el.querySelector('a');
      return link?.href || null;
    })()
  `
};

export async function find_coords(imagePath: string, prompt: string, targetId?: string): Promise<{ x: number, y: number }> {
  const apiKey = process.env.MOONDREAM;
  if (!apiKey) throw new Error('MOONDREAM env var not set');

  let width: number, height: number;

  if (targetId) {
    const viewport = await cdp_eval(js_snippets.viewport, targetId);
    const parsed = JSON.parse(viewport as string);
    width = parsed.width;
    height = parsed.height;
  } else {
    const { $ } = await import('bun');
    const sipsOutput = await $`sips -g pixelWidth -g pixelHeight ${imagePath}`.text();
    width = parseInt(sipsOutput.match(/pixelWidth: (\d+)/)?.[1] || '0');
    height = parseInt(sipsOutput.match(/pixelHeight: (\d+)/)?.[1] || '0');
  }

  const model = new vl({ apiKey });
  const imageData = await Bun.file(imagePath).arrayBuffer();

  const result = await model.point({
    image: Buffer.from(imageData),
    object: prompt
  });

  if (result.points.length === 0) {
    throw new Error(`no match found for: ${prompt}`);
  }

  const point = result.points[0];
  return {
    x: Math.round(point.x * width),
    y: Math.round(point.y * height)
  };
}

export const img_path = (name: string) => `/tmp/br_${name}.png`;

