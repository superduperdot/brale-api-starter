# Cloudflare platform

Field notes for Cloudflare Workers, D1, Durable Objects, and Queues across architectures. Architecture: cross-cutting (see [cloudflare-stack.md](../guide/cloudflare-stack.md)).

### Queue delivery paused while send() succeeded

- **What happened:** Messages were sent to a queue successfully, but delivery to the consumer was paused. Messages accumulated silently. Production observed 0.9% effective delivery until the pause was noticed.
- **Do this instead:** Check queue delivery status before relying on it. Prefer HTTP POST or service bindings for coordination. Use Queues for write-behind archives only.
- **Guide:** [Cloudflare — Queues](../guide/cloudflare-stack.md)

### Two consumers bound to the same queue

- **What happened:** Two Workers were bound as consumers for the same queue. The last deploy silently won; the other was disconnected without error. Finalize messages from the displaced consumer were lost.
- **Do this instead:** Exactly one consumer per queue. If you need fan-out, use HTTP POST from one consumer to the others.
- **Guide:** [Cloudflare — Queues](../guide/cloudflare-stack.md)

### Durable Object migration tag collision

- **What happened:** A new DO class was added under the same `new_sqlite_classes` migration tag as existing classes. The migration failed or behaved unpredictably.
- **Do this instead:** Each new DO class gets its own migration tag in the wrangler config.
- **Guide:** [Durable Objects](../guide/durable-objects.md)

### Vite proxy target wrong port

- **What happened:** The Vite dev server proxy pointed at port 8787. Wrangler was actually on 8788. Requests returned an HTML error page instead of JSON.
- **Do this instead:** Match the proxy target to the port wrangler actually prints on startup (often 8788).
- **Guide:** [Cloudflare — gotchas](../guide/cloudflare-stack.md)

### Node and Workers type conflicts

- **What happened:** Worker code imported a Node-typed module. `Request` and `Response` type collisions caused build failures.
- **Do this instead:** Split `tsconfig.worker.json` for DO/Worker code. Only that subtree includes Cloudflare worker types.
- **Guide:** [Cloudflare — local development](../guide/cloudflare-stack.md)
