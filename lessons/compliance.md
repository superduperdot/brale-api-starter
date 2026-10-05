# Compliance monitoring

Field notes for screening and investigation. Architecture: [concepts.md](../guide/concepts.md#compliance-monitoring).

### One Worker did both jobs

- **What happened:** Queue consumers on the API Worker spiked latency for investigators.
- **Do this instead:** An API Worker and a processor Worker. Queues carry scoring and ingest, not the request the investigator is waiting on.
- **Guide:** [Cloudflare — Workers](../guide/cloudflare-stack.md)

### Screening in vendor vocabulary

- **Do this instead:** Model every movement as a leg `(ValueType, TransferType, Amount)`. Join exchanges into a funds flow. Map a vendor `{network, asset}` pair to `{transferType, valueType}` with the Brale registry, cached in KV.
- **Guide:** [Value Layer](../guide/value-layer.md), [CSF and GSF](../guide/csf-gsf.md)

### Funds flow as a picture

- **Do this instead:** Render CSF (Mermaid, Light density is enough to start) from the legs you already store. Add a route that returns the flow for one subject.
- **Guide:** [CSF and GSF](../guide/csf-gsf.md)

### Relationships are not a sequence

- **Do this instead:** A hop-limited graph with value-type and transfer-type edge labels covers the structural question. Export a formal GSF dataset when another tool needs to ingest it. Keep CSF beside it if order matters.
- **Guide:** [CSF and GSF](../guide/csf-gsf.md)

### Durable Objects as a throughput tier

- **Do this instead:** A Durable Object per organization for screening state, one object (or a small set) for scheduled re-screening via alarms, and one per API key for rate limits. Fan-out stays on Queues.
- **Guide:** [Cloudflare — Durable Objects](../guide/cloudflare-stack.md)

### Sanctions false negatives

- **What happened:** The same EVM address in mixed case did not match the list.
- **Do this instead:** Lowercase EVM addresses before you store and before you compare. A miss here is a legal problem, not a display bug.
- **Guide:** [Security](../guide/security.md)

### Naming the exchange

- **Do this instead:** Value type changed, transfer type did not: swap. Transfer type changed, value type did not: bridge. Both changed: cross-rail.
- **Guide:** [Value Layer](../guide/value-layer.md)

### Sessions in KV

- **Do this instead:** KV can hold the registry cache. It cannot hold sessions or authorization.
- **Guide:** [Cloudflare — KV](../guide/cloudflare-stack.md), [Security](../guide/security.md)

### Screening data licenses

- **Do this instead:** Confirm the dataset’s license (commercial screening feeds are often not free for production) before you depend on it.
- **Guide:** [Security](../guide/security.md)

### Empty investigations in dev

- **Do this instead:** Import production-shaped transfers for walkthroughs. Do not use live customer data as the demo set.
- **Guide:** [Testing](../guide/testing.md)
