# Copyright © 2020 Trey Cutter <treycutter@protonmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
#
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import tables, strutils
import cairo as cairo
import colors, macros

when defined linux:
  import
    x11/x
elif defined android:
  import private/egl
elif defined windows:
  import winim

type
  UiNative* = ref object
    ctx*: ptr cairo.Context
    surface*: ptr Surface
    width*, height*: int
    received_event*: proc(ev: UiEvent) {.gcsafe.}
    when defined(linux):
      xwindow*: Window
    when defined(android):
      eglsurface*: EGLSurface
    when defined(windows):
      hwnd*: HWND

  UiEventMod* = enum
    UiEventPress, UiEventRelease, UiEventMotion
    UiEventExpose, UiEventResize, UiEventEnter,
    UiEventLeave

  UiEvent* = object
    event_mod*: UiEventMod
    button*, x*, y*, xroot*, yroot*, key*, w*, h*: int
    ch*: string
    native*: UiNative

  UiEventCallback* = proc(ev: UiEvent) {.gcsafe.}

type
  UiModelTable* = OrderedTable[int, string]

  UiModel* = ref object
    list*: seq[UiModelTable]
    count*: int
    table_added*, table_removed*: proc(index: int)

type
  UiAnchor* = distinct float32

  UiAlignment* = enum
    UiRight, UiCenter, UiLeft
    UiTop, UiBottom

  UpdateAttributesCb* = proc(self, parent: UiNode)
  OnEventCb* = proc(self, parent: UiNode, event: var UiEvent)
  DrawPostCb* = proc()

  UiNodeKind* = enum
    UiWindow, UiBox, UiText,
    UiImage, UiCanvas, UiLayout

  UiNode* = ref object
    parent*, window*: UiNode
    surface*: cairo.PSurface
    children*: seq[UiNode]
    id*: string
    x*, y*, w*, h*: float32
    margin_top*, margin_left*, margin_bottom*, margin_right*: float32
    model*: UiModel
    clip*, visible*, hovered*, has_focus*, wants_focus*, animating*,
        need_redraw*: bool
    update_attributes*: seq[UpdateAttributesCb]
    on_event*: seq[OnEventCb]
    draw_post*: seq[DrawPostCb]
    index*: int
    color*, foreground*: colors.Color
    opacity*: range[0f..1f]
    left_anchored*, top_anchored*: bool
    case kind*: UiNodeKind
    of UiBox:
      radius*: float32
      border_top*, border_left*, border_bottom*, border_right*: float32
      border_color*: colors.Color
    of UiWindow:
      title*: string
      exposed*, is_popup*: bool
      focused_node*: UiNode
      native*: UiNative
    of UiText:
      text*, family*: string
      valign*, halign*: UiAlignment
    of UiCanvas:
      paint*: proc(ctx: ptr cairo.Context)
    of UiLayout:
      spacing*: float32
      delegates: seq[UiNode]
      delegate*: proc(model: UiModel, index: int): UiNode
      arrange_layout*: proc()
    of UiImage:
      src: string

var
  oui_framecount* = 0
  oui_natives*: seq[UiNative] = @[]

macro exposecb*(x, y, native: untyped) =
  result = parse_stmt("""
$1.received_event((UiEvent(
  event_mod: UiEventExpose,
  button: -1,
  x: $2,
  y: $3,
  xroot: -1,
  yroot: -1,
  w: -1,
  h: -1,
  key: -1,
  ch: "",
  native: $1)))
 
""" % [native.repr, x.repr, y.repr])

macro keycb*(kind, x, y, key, ch, native: untyped) =
  result = parse_stmt("""
$1.received_event((UiEvent(
  event_mod: $6,
  button: -1,
  x: $2,
  y: $3,
  xroot: -1,
  yroot: -1,
  w: -1,
  h: -1,
  key: $4,
  ch: $5,
  native: $1)))
 
""" % [native.repr, x.repr, y.repr, key.repr, ch.repr, kind.repr])

macro buttoncb*(kind, button, x, y, xroot, yroot, native: untyped) =
  result = parse_stmt("""
$1.received_event((UiEvent(
  event_mod: $7,
  button: $2,
  x: $3,
  y: $4,
  xroot: $5,
  yroot: $6,
  w: -1,
  h: -1,
  key: -1,
  ch: "",
  native: $1)))
 
""" % [native.repr, button.repr, x.repr, y.repr, xroot.repr, yroot.repr, kind.repr])

macro motioncb*(x, y, xroot, yroot, native: untyped) =
  result = parse_stmt("""
$1.received_event((UiEvent(
  event_mod: UiEventMotion,
  button: -1,
  x: $2,
  y: $3,
  xroot: $4,
  yroot: $5,
  w: -1,
  h: -1,
  key: -1,
  ch: "",
  native: $1)))
 
""" % [native.repr, x.repr, y.repr, xroot.repr, yroot.repr])

macro resizecb*(width, height, native: untyped) =
  result = parse_stmt("""
$1.received_event((UiEvent(
  event_mod: UiEventResize,
  button: -1,
  x: -1,
  y: -1,
  xroot: -1,
  yroot: -1,
  w: $2,
  h: $3,
  key: -1,
  ch: "",
  native: $1)))
 
""" % [native.repr, width.repr, height.repr])
