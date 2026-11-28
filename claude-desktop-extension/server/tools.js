import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import { BridgeError } from './bridge_client.js';

const text = (value, isError = false) => ({
  content: [{ type: 'text', text: typeof value === 'string' ? value : JSON.stringify(value, null, 2) }],
  ...(isError ? { isError: true } : {}),
});

const failure = (error) =>
  text(error instanceof BridgeError ? error.message : `Unexpected error: ${error?.message ?? error}`, true);

const STATUS_HELP = {
  starting: 'Bridge is starting the task.',
  running: 'The task is running.',
  waiting_for_approval: 'The user must approve this action in the Brigade Bridge window before it can run.',
  paused: 'The target app is unavailable, so Bridge paused the task.',
  unknown: 'The connection to Bridge was lost; the task may still be running there.',
};

function describe(job) {
  const base = { job_id: job.id, node: `${job.nodeName} (${job.nodeId})`, status: job.status };
  if (job.status === 'completed') return { ...base, result: job.result };
  if (job.error) return { ...base, error: job.error };
  return { ...base, note: STATUS_HELP[job.status] ?? '' };
}

const waitSchema = z
  .number()
  .int()
  .min(0)
  .max(55)
  .optional()
  .describe('Seconds to wait for the result before returning (default 45). Use bridge_get_result to keep waiting.');

/** Builds the MCP server. `client` is a BridgeClient (or a test double). */
export function createServer(client) {
  const server = new McpServer({ name: 'brigade-bridge', version: '0.1.0' });

  server.registerTool(
    'bridge_list_nodes',
    {
      title: 'List Bridge apps',
      description:
        'Lists the apps the user has connected to Brigade Bridge (for example Codex, Antigravity, Claude Code, or a browser tab) that can receive a delegated task. Returns each app\'s id and name.',
      inputSchema: {},
      annotations: { readOnlyHint: true, openWorldHint: false },
    },
    async () => {
      try {
        const nodes = await client.listNodes();
        if (nodes.length === 0) {
          return text('No apps are connected to Brigade Bridge yet. The user can connect them in Bridge under Overlay settings.');
        }
        return text(nodes.map(({ id, name, kind, taskDomains }) => ({ id, name, ...(kind ? { kind } : {}), ...(taskDomains ? { task_domains: taskDomains } : {}) })));
      } catch (error) {
        return failure(error);
      }
    },
  );

  server.registerTool(
    'bridge_delegate',
    {
      title: 'Delegate a task to another app',
      description:
        'Sends a self-contained task to another app connected to Brigade Bridge and returns its answer. Only use this when the user asked you to involve that app, or clearly wants it. Include everything the app needs in the instruction; it cannot see this conversation. Never include passwords, tokens or other secrets. Bridge may ask the user to approve the task in its own window first; tell the user if the status is waiting_for_approval. Only one delegation can run at a time. If the answer is not ready in time you get a job_id; call bridge_get_result to keep waiting.',
      inputSchema: {
        node_id: z.string().min(1).max(256).describe('The id of the target app, from bridge_list_nodes'),
        instruction: z.string().min(1).max(20_000).describe('The complete task for the other app'),
        project_id: z.string().min(1).max(128).optional().describe('Bridge project context id; defaults to the active/default project'),
        wait_seconds: waitSchema,
      },
      annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: true },
    },
    async ({ node_id, instruction, project_id, wait_seconds }) => {
      try {
        const job = await client.startJob({ nodeId: node_id, instruction, projectId: project_id });
        await client.waitForJob(job, wait_seconds ?? 45);
        return text(describe(job), job.status === 'failed' || job.status === 'stopped' || job.status === 'cancelled');
      } catch (error) {
        return failure(error);
      }
    },
  );

  server.registerTool(
    'bridge_get_result',
    {
      title: 'Get a delegated task result',
      description: 'Waits for (or checks) a task started with bridge_delegate and returns its status and answer.',
      inputSchema: {
        job_id: z.string().min(1).max(128),
        wait_seconds: waitSchema,
      },
      annotations: { readOnlyHint: true, openWorldHint: false },
    },
    async ({ job_id, wait_seconds }) => {
      try {
        const job = client.getJob(job_id);
        await client.waitForJob(job, wait_seconds ?? 45);
        return text(describe(job), job.status === 'failed' || job.status === 'stopped' || job.status === 'cancelled');
      } catch (error) {
        return failure(error);
      }
    },
  );

  server.registerTool(
    'bridge_cancel',
    {
      title: 'Cancel a delegated task',
      description: 'Asks Brigade Bridge to cancel the workflow started by bridge_delegate. Use it if the user changes their mind or the task is stuck.',
      inputSchema: { job_id: z.string().min(1).max(128) },
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false },
    },
    async ({ job_id }) => {
      try {
        const job = await client.cancelJob(job_id);
        return text({ ...describe(job), note: 'Cancellation was requested; call bridge_get_result to confirm.' });
      } catch (error) {
        return failure(error);
      }
    },
  );

  return server;
}
