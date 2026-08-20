# App Intents

PageLumen exposes local-library actions to Shortcuts and Siri without sending
document text to a server.

## Export Tagged HTML

`ExportTaggedHTMLIntent` takes a retained local-library document and a
caller-provided destination file URL. The destination must be selected by the
caller (for example, a Shortcuts File action); the intent never opens an
`NSSavePanel` or asks for an interactive path while running.

The intent loads only the selected document from the local repository, runs the
same Tagged HTML validation as the in-app export screen, and writes the result
atomically. If the document is missing, validation blocks export, or the file
cannot be written, it returns a dialog explaining the unavailable result.

The action is intentionally local-only. It does not upload document content,
and the destination URL is supplied explicitly by the user’s automation.
