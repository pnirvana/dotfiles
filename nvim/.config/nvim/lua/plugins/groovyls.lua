return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      groovyls = {
        mason = false, -- important: don't let Mason manage it
        cmd = {
          "java",
          "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005",
          "-jar",
          vim.fn.expand("~/Dev/groovy-language-server/build/libs/groovy-language-server-all.jar"),
        },
        filetypes = { "groovy" },
      },
    },
  },
}
