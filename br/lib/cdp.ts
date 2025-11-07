export async function listTargets() {
  const response = await fetch('http://localhost:9228/json');
  return await response.json();
}

export async function getTarget(targetId?: string) {
  const targets = await listTargets();
  
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

export async function cdpEval(expression: string, targetId?: string, returnByValue = true) {
  const tab = await getTarget(targetId);
  const ws = new WebSocket(tab.webSocketDebuggerUrl);
  
  return new Promise((resolve, reject) => {
    ws.addEventListener('open', () => {
      ws.send(JSON.stringify({
        id: 1,
        method: 'Runtime.evaluate',
        params: { expression, returnByValue }
      }));
    });

    ws.addEventListener('message', (event: any) => {
      const result = JSON.parse(event.data);
      if (result.id === 1) {
        ws.close();
        if (result.error) {
          reject(new Error(result.error.message));
        } else {
          resolve(result.result.result.value);
        }
      }
    });

    ws.addEventListener('error', () => {
      reject(new Error('websocket error'));
    });
  });
}

export async function cdpCommand(method: string, params: any = {}, targetId?: string) {
  const tab = await getTarget(targetId);
  const ws = new WebSocket(tab.webSocketDebuggerUrl);
  
  return new Promise((resolve, reject) => {
    ws.addEventListener('open', () => {
      ws.send(JSON.stringify({ id: 1, method, params }));
    });

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

    ws.addEventListener('error', () => {
      reject(new Error('websocket error'));
    });
  });
}
