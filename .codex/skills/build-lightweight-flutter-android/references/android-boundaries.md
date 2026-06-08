# Android File And App Boundaries

## Storage choices

| Need | Android mechanism | Typical behavior |
|---|---|---|
| Internal working file | App-private directory | Hidden from gallery; removed on uninstall |
| Open/share private file | FileProvider | Read-only `content://` URI for another app |
| Public image/audio/video | MediaStore | Visible to media apps |
| User-selected destination | Storage Access Framework | User controls document location |
| App-specific external file | External files directory | No broad permission; usually hidden from gallery |

Never assume `getApplicationDocumentsDirectory()` maps to Android `files/`. Verify the real path and
align `FileProvider` roots with it.

## Sharing semantics

The receiving app controls what happens after Android delivers the URI.

- Media MIME such as `image/png` may trigger preview, compression, renaming, or transcoding.
- Generic `application/octet-stream` encourages file-attachment handling.
- A chat app's "save image" action can create a new file unrelated to the original extension.
- Verify conversion using the produced file, file header, or downloaded original attachment.

## Permissions

- Reading user-selected files through the system picker usually relies on granted URI access.
- Writing app-created media through MediaStore on modern Android normally does not require broad
  storage permission.
- Old Android versions may need legacy write permission.
- Debug manifests may add Internet permission for hot reload; inspect release manifests separately.

## FileProvider checks

When seeing `Failed to find configured root that contains ...`:

1. Read the failing absolute path.
2. Compare it with every path configured in `res/xml/file_paths.xml`.
3. Determine whether it is under `files`, cache, external files, or another app-private directory.
4. Grant only the narrow output directory.
5. Rebuild and inspect the packaged resource, not just the source XML.

## Public copy lifecycle

If exporting a private result to MediaStore, decide:

- whether history points to the private file or public URI
- whether deleting history deletes the public copy
- what happens when one copy is removed externally
- how duplicate names are handled
- whether failed writes remove pending MediaStore rows
