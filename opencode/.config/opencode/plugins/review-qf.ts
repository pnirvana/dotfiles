import type { Plugin } from "@opencode-ai/plugin"
import path from "path"
import fs from "fs"

const log = (msg: string) =>
  fs.appendFileSync("/tmp/opencode-review-qf.log", `${new Date().toISOString()} ${msg}\n`)

export const ReviewQuickfix: Plugin = async ({ $, directory }) => {
  log("plugin initialized, directory: " + directory)
  return {
    "tool.execute.after": async (input) => {
      if (
        input.tool === "apply_patch" &&
        input.args?.patchText?.includes(".opencode/review_findings.txt")
      ) {
        const findingsFile = path.join(directory, ".opencode/review_findings.txt")
        const socket = process.env.NVIM ?? process.env.NVIM_LISTEN_ADDRESS
        log("triggering quickfix, socket: " + socket)
        if (!socket) return
        await $`nvim --server ${socket} --remote-expr "execute('ReviewFindings')"`
        log("RPC call sent")
      }
    }
  }
}
