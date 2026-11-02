-- Example editor script: Tools menu item that logs.
Editor.MenuItem("Tools/Hello Editor Script", function()
    Editor.Log("Hello from Editor Script")
end, {
    description = "Log a hello message from an editor script",
})
