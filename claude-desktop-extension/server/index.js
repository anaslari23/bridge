#!/usr/bin/env node
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { BridgeClient, DEFAULT_URL } from './bridge_client.js';
import { createServer } from './tools.js';

// stdout carries the MCP protocol, so diagnostics go to stderr only.
const url = process.env.BRIDGE_URL?.trim() || DEFAULT_URL;
const token = process.env.BRIDGE_TOKEN?.trim() || undefined;

let client;
try {
  client = new BridgeClient({ url, token });
} catch (error) {
  console.error(`brigade-bridge extension: ${error.message}`);
  process.exit(1);
}

const server = createServer(client);
await server.connect(new StdioServerTransport());

const shutdown = () => {
  client.close();
  process.exit(0);
};
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
process.stdin.on('end', shutdown);
