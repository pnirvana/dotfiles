return {
  "nvim-java/nvim-java",
  config = function()
    require("java").setup()
    vim.lsp.enable("jdtls")

    -- Java-only mappings (buffer-local, created for every Java buffer)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "java",
      callback = function(ev)
        local map = vim.keymap.set
        local opts = { buffer = ev.buf, silent = true }

        -- Optional: ensure which-key shows a "Java" group label
        pcall(function()
          require("which-key").add({ { "<leader>j", group = "Java" } })
        end)

        -- Build
        map(
          "n",
          "<leader>jb",
          "<cmd>JavaBuildBuildWorkspace<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: Build workspace" })
        )
        map(
          "n",
          "<leader>jB",
          "<cmd>JavaBuildCleanWorkspace<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: Clean workspace cache" })
        )

        -- Runner
        map(
          "n",
          "<leader>jm",
          "<cmd>JavaRunnerRunMain<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: Run main()" })
        )
        map(
          "n",
          "<leader>jM",
          "<cmd>JavaRunnerStopMain<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: Stop main()" })
        )
        map(
          "n",
          "<leader>jl",
          "<cmd>JavaRunnerToggleLogs<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: Toggle runner logs" })
        )

        -- DAP
        map(
          "n",
          "<leader>jdc",
          "<cmd>JavaDapConfig<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: DAP re-configure" })
        )

        -- Tests
        map(
          "n",
          "<leader>jtc",
          "<cmd>JavaTestRunCurrentClass<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: Test current class" })
        )
        map(
          "n",
          "<leader>jtC",
          "<cmd>JavaTestDebugCurrentClass<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: Debug current class tests" })
        )

        map(
          "n",
          "<leader>jtm",
          "<cmd>JavaTestRunCurrentMethod<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: Test current method" })
        )
        map(
          "n",
          "<leader>jtM",
          "<cmd>JavaTestDebugCurrentMethod<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: Debug current method test" })
        )

        map(
          "n",
          "<leader>jta",
          "<cmd>JavaTestRunAllTests<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: Test all workspace" })
        )
        map(
          "n",
          "<leader>jtA",
          "<cmd>JavaTestDebugAllTests<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: Debug all workspace tests" })
        )

        map(
          "n",
          "<leader>jtr",
          "<cmd>JavaTestViewLastReport<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: View last test report" })
        )

        -- Profiles
        map("n", "<leader>jp", "<cmd>JavaProfile<cr>", vim.tbl_extend("force", opts, { desc = "Java: Profiles" }))

        -- Refactor (works in normal/visual where applicable)
        map(
          { "n", "v" },
          "<leader>jrv",
          "<cmd>JavaRefactorExtractVariable<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: Extract variable" })
        )
        map(
          { "n", "v" },
          "<leader>jrV",
          "<cmd>JavaRefactorExtractVariableAllOccurrence<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: Extract variable (all)" })
        )
        map(
          { "n", "v" },
          "<leader>jrc",
          "<cmd>JavaRefactorExtractConstant<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: Extract constant" })
        )
        map(
          { "n", "v" },
          "<leader>jrm",
          "<cmd>JavaRefactorExtractMethod<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: Extract method" })
        )
        map(
          { "n", "v" },
          "<leader>jrf",
          "<cmd>JavaRefactorExtractField<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: Extract field" })
        )

        -- Settings
        map(
          "n",
          "<leader>jj",
          "<cmd>JavaSettingsChangeRuntime<cr>",
          vim.tbl_extend("force", opts, { desc = "Java: Change runtime (JDK)" })
        )
      end,
    })
  end,
}
