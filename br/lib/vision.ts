import { vl } from 'moondream';
import { cdpEval } from './cdp';

export async function findCoords(imagePath: string, prompt: string, targetId?: string): Promise<{ x: number, y: number }> {
  const apiKey = process.env.MOONDREAM;
  if (!apiKey) {
    throw new Error('MOONDREAM env var not set');
  }

  const viewport = await cdpEval(
    'JSON.stringify({ width: window.innerWidth, height: window.innerHeight })',
    targetId
  );
  const { width, height } = JSON.parse(viewport as string);

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

