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

import macros, strutils, colors, cairo
import types, node

var
  ctx*: ptr Context
  parents* {.compileTime.}: seq[NimNode] = @[]

macro node_init*(id: untyped, kind: UiNodeKind): untyped =
  var self_id = id.str_val
  result = quote do:
    UiNode.init `self_id`, `kind`

macro node_next_parent(id: untyped, delegate: bool = false) =
  var current_parent = if parents.len > 0: parents[parents.high] else: new_nil_lit()
  if current_parent.kind != nnkNilLit and delegate.bool_val == false:
    result = quote do:
      `current_parent`.add(`id`)
  parents.add(id)

template node*(id: untyped, kind: UiNodeKind, inner: untyped,
    delegate: bool = false) =
  expandMacros:
    var id {.inject.} = node_init(id, kind)
    self  = id
    node_next_parent(id, delegate)
    parent = prev_parent
    prev_parent = id
    inner
  static:
    if parents.len > 0:
      discard parents.pop()

var noid_count* {.compileTime.}: int
macro node_without_id*(name, inner: untyped) =
  noid_count.inc
  var noid = ident("noid" & $noid_count)
  result = quote do:
    `name` `noid`, `inner`
    
template decl_ui_node*(name: untyped, kind: UiNodeKind) =
  template name*(id: untyped, inner: untyped) =
    node id, kind, inner, false
  template name*(inner: untyped) =
    node_without_id name, inner

decl_ui_node window, UiWindow
decl_ui_node box, UiBox
decl_ui_node text, UiText
decl_ui_node canvas, UiCanvas
decl_ui_node layout, UiLayout

template model*(m: UiModel) =
  node_self().set_model m

template delegate*(call: untyped, kind: UiNodeKind, inner: untyped) =
  node_self().delegate = proc(tmpmodel: UiModel, tmpindex: int): UiNode =
    var
      model {.inject.} = tmpmodel
      index {.inject.} = tmpindex
    node delegate, kind, inner, true
    return delegate

template paint*(inner: untyped) =
  self.paint = proc(tmpctx: ptr Context) {.closure.} =
    ctx = tmpctx
    `inner`

template top*(anchor: UiAnchor) =
  self.set_top anchor

template left*(anchor: UiAnchor) =
  self.set_left anchor

template bottom*(anchor: UiAnchor) =
  self.set_bottom anchor

template right*(anchor: UiAnchor) =
  self.set_right anchor

template margin_top*(m: float32) =
  self.margin_top = m

template margin_left*(m: float32) =
  self.margin_left = m

template margin_bottom*(m: float32) =
 self.margin_bottom = m

template margin_right*(m: float32) =
  self.margin_right = m

template margin*(top, left, bottom, right: float32) =
  self.margin_top = top
  self.margin_left = left
  self.margin_bottom = bottom
  self.margin_right = right

template border_top*(m: float32) =
  self.border_top = m

template border_left*(m: float32) =
  self.border_left = m

template border_bottom*(m: float32) =
  self.border_bottom = m

template border_right*(m: float32) =
  self.border_right = m

template border*(top, left, bottom, right: float32) =
  self.border_top = top
  self.border_left = left
  self.border_bottom = bottom
  self.border_right = right

template border_color*(c: Color) =
  self.color = c

template border_color*(r, g, b: int = 255) =
  self.color = rgb(r, g, b)

template border_color*(c: string) =
  self.color = parse_color(c)

template color*(c: Color) =
  self.color = c

template color*(r, g, b: int = 255) =
  self.color = rgb(r, g, b)

template color*(c: string) =
  self.color = parse_color(c)

template foreground*(r, g, b: int = 255) =
  self.foreground = rgb(r, g, b)

template foreground*(c: string) =
  self.foreground = parse_color(c)

template foreground*(c: Color) =
  self.foreground = c

template opacity*(o: range[0f..1f]) =
  self.opacity = o

template w*(width: float32) =
  self.w = width

template h*(height: float32) =
  self.h = height

template size*(width, height: float32) =
  self.w = width
  self.h = height

template fill*(target: UiNode) =
  self.fill(target)

template vcenter*(target: UiNode) =
  self.vcenter(target)

template hcenter*(target: UiNode) =
  self.hcenter(target)

template visible*(b: bool) =
  self.visible = b

template center*(target: UiNode) =
  self.center(target)

template title*(str: string) =
  self.title = str

template text*(str: string) =
  self.text = str

template family*(str: string) =
  self.family = str

template valign*(align: UiAlignment) =
  self.valign = align

template halign*(align: UiAlignment) =
  self.halign = align

template radius*(r: float32) =
  self.radius = r

template spacing*(s: float32) =
  self.spacing = s

template update*(inner: untyped) =
  self.update_attributes.add proc(s, p: UiNode) {.closure.} =
    self = s
    parent = p
    `inner`

template events*(inner: untyped) =
  self.on_event.add proc(s, p: UiNode, e: var UiEvent) {.closure.} =
    event = e
    self = s
    parent = p
    `inner`

template key_press*(inner: untyped) =
  if event.event_mod == UiEventPress and event.key != -1:
    `inner`

template key_release*(inner: untyped) =
  if event.event_mod == UiEventRelease and event.key != -1:
    `inner`

template button_press*(inner: untyped) =
  if event.event_mod == UiEventPress and event.button != -1:
    `inner`

template button_release*(inner: untyped) =
  if event.event_mod == UiEventRelease and event.button != -1:
    `inner`

template mouse_motion*(inner: untyped) =
  if event.event_mod == UiEventMotion:
    `inner`

template mouse_enter*(inner: untyped) =
  if event.event_mod == UiEventEnter:
    `inner`

template mouse_leave*(inner: untyped) =
  if event.event_mod == UiEventLeave:
    `inner`

template arrange_layout*(inner: untyped) =
  self.arrange_layout = proc() {.closure.} =
    `inner`

when defined(testing) and is_main_module:
  import unittest
  suite "sugarsyntax":
    test "children":
      box box1:
        box box2:
          box box3:
            discard
          box box4:
            discard
        box box5:
          discard
        box box6:
          box box7:
            discard
      check box1.children.len == 3
      check box2.children.len == 2
      check box3.children.len == 0
      check box4.children.len == 0
      check box5.children.len == 0
      check box6.children.len == 1
      check box7.children.len == 0

    test "attributes":
      box:
        w 10
        h 10
        size self.w * 2, self.h * 2
        check self.w == 20
        check self.h == 20
        
        top self.top
        left self.left
        bottom self.bottom
        right self.right

        color "#eeeeee"
        color 255, 255, 255
        foreground "#eeeeee"
        foreground 255, 255, 255
        color self.foreground
        foreground self.color
        opacity 0.5
        radius 5
      text:
        fill self
        vcenter self
        hcenter self
        center self
        valign UiBottom
        halign UiRight

        text "something else"
        family "something else x3"
        visible true
      window:
        title "something"