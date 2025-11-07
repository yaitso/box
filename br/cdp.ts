export async function list_targets(): Promise<any[]> {
  const response = await fetch('http://localhost:9228/json');
  return await response.json();
}

export async function get_target(targetId?: string) {
  const targets = await list_targets();
  
  if (targetId) {
    const target = targets.find((t: any) => t.id === targetId);
    if (!target) throw new Error(`target not found: ${targetId}`);
    return target;
  }
  
  const activeTab = targets.find((t: any) => t.type === 'page') || targets[0];
  if (!activeTab?.webSocketDebuggerUrl) {
    throw new Error('no active browser tab');
  }
  
  return activeTab;
}

async function cdp_ws<T>(targetId: string | undefined, handler: (ws: WebSocket) => void): Promise<T> {
  const tab = await get_target(targetId);
  const ws = new WebSocket(tab.webSocketDebuggerUrl);
  
  return new Promise((resolve, reject) => {
    ws.addEventListener('open', () => handler(ws));

    ws.addEventListener('message', (event: any) => {
      const result = JSON.parse(event.data);
      if (result.id === 1) {
        ws.close();
        if (result.error) {
          reject(new Error(result.error.message));
        } else {
          resolve(result.result);
        }
      }
    });

    ws.addEventListener('error', () => reject(new Error('websocket error')));
  });
}

export async function cdp_eval(expression: string, targetId?: string, returnByValue = true) {
  const result: any = await cdp_ws(targetId, ws => {
    ws.send(JSON.stringify({
      id: 1,
      method: 'Runtime.evaluate',
      params: { expression, returnByValue }
    }));
  });
  return result.result.value;
}

export async function cdp_cmd(method: string, params: any = {}, targetId?: string) {
  return cdp_ws(targetId, ws => {
    ws.send(JSON.stringify({ id: 1, method, params }));
  });
}
