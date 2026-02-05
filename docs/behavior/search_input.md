# 搜索输入（Type-to-Search）行为说明

## 目标
在应用主页或其他 Tab 页面中，用户直接键盘输入时，应自动聚焦到搜索框并把输入内容写入。

## 现状实现
- 在主页根部增加全局 `Focus`，监听 `onKeyEvent`（仅在没有文本输入焦点时生效）。
- 当捕获到可打印字符：
  1. 自动切换到 **应用 Tab**
  2. 聚焦搜索框
  3. 将字符写入搜索框并更新搜索结果

## 关键代码
- `lib/screens/desk_tidy_home/state.dart`：根部 `Focus` 与全局焦点节点
- `lib/screens/desk_tidy_home/logic_search.dart`：`_handleGlobalKeyEvent()` 输入转发逻辑

## 注意事项
- 如果当前已有文本输入控件聚焦，则不会劫持按键，避免干扰设置页输入。

