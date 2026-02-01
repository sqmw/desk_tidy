part of '../desktop_helper.dart';

class IImageList extends IUnknown {
  IImageList(super.ptr);

  int getIcon(int i, int flags, Pointer<IntPtr> icon) => (ptr.ref.vtable + 10)
      .cast<
        Pointer<
          NativeFunction<Int32 Function(Pointer, Int32, Int32, Pointer<IntPtr>)>
        >
      >()
      .value
      .asFunction<
        int Function(Pointer, int, int, Pointer<IntPtr>)
      >()(ptr.ref.lpVtbl, i, flags, icon);
}

class _IconLocation {
  final String path;
  final int index;

  const _IconLocation(this.path, this.index);
}

class _IconCacheResult {
  final bool found;
  final Uint8List? value;

  const _IconCacheResult({required this.found, this.value});
}
