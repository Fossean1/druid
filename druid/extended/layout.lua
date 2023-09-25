-- Copyright (c) 2021 Maksim Tuprikov <insality@gmail.com>. This code is licensed under MIT license

--- Layout management on node
--
-- <a href="https://insality.github.io/druid/druid/index.html?example=general_layout" target="_blank"><b>Example Link</b></a>
-- @module Layout
-- @within BaseComponent
-- @alias druid.layout

--- Layout node
-- @tfield node node

--- Current layout mode
-- @tfield string mode

---On window resize callback(self, new_size)
-- @tfield DruidEvent on_size_changed @{DruidEvent}

---


local const = require("druid.const")
local helper = require("druid.helper")
local component = require("druid.component")
local Event = require("druid.event")


local Layout = component.create("layout")


--- Component init function
-- @tparam Layout self @{Layout}
-- @tparam node node Gui node
-- @tparam string mode The layout mode (from const.LAYOUT_MODE)
-- @tparam[opt] function on_size_changed_callback The callback on window resize
function Layout.init(self, node, mode, on_size_changed_callback)
	self.node = self:get_node(node)
	self.druid = self:get_druid()

	self._min_size = nil
	self._max_size = nil
	self._current_size = vmath.vector3(0)
	self._inited = false
	self._max_gui_upscale = nil
	self._fit_node = nil

	self._anchors = {}
	self._draggable_corners = {}

	local node_size = gui.get_size(self.node)
	self.pivot_offset = helper.get_pivot_offset(gui.get_pivot(self.node))
	self.center_offset = -vmath.vector3(node_size.x * self.pivot_offset.x, node_size.y * self.pivot_offset.y, 0)

	self.mode = mode or const.LAYOUT_MODE.FIT

	self.on_size_changed = Event(on_size_changed_callback)
end


function Layout.on_late_init(self)
	self._inited = true
	self.origin_size = self.origin_size or gui.get_size(self.node)
	self.fit_size = self.fit_size or vmath.vector3(self.origin_size)
	self.pivot_offset = helper.get_pivot_offset(gui.get_pivot(self.node))
	self.center_offset = -vmath.vector3(self.origin_size.x * self.pivot_offset.x, self.origin_size.y * self.pivot_offset.y, 0)
	self.origin_position = gui.get_position(self.node)
	self.position = vmath.vector3(self.origin_position)
	gui.set_size_mode(self.node, gui.SIZE_MODE_MANUAL)
	gui.set_adjust_mode(self.node, gui.ADJUST_FIT)

	self:on_window_resized()
	self:update_anchors()
end


--- Component style params.
-- You can override this component styles params in Druid styles table
-- or create your own style
-- @table style
-- @tfield[opt=vector3(24, 24, 0)] vector3 DRAGGABLE_CORNER_SIZE Size of box node for debug draggable corners
-- @tfield[opt=vector4(1)] vector4 DRAGGABLE_CORNER_COLOR Color of debug draggable corners
function Layout.on_style_change(self, style)
	self.style = {}
	self.style.DRAGGABLE_CORNER_SIZE = style.DRAGGABLE_CORNER_SIZE or vmath.vector3(24, 24, 0)
	self.style.DRAGGABLE_CORNER_COLOR = style.DRAGGABLE_CORNER_COLOR or vmath.vector4(1)
end


function Layout.on_window_resized(self)
	if not self._inited then
		return
	end

	local x_koef, y_koef = helper.get_screen_aspect_koef()

	local revert_scale = 1
	if self._max_gui_upscale then
		revert_scale = self._max_gui_upscale / helper.get_gui_scale()
		revert_scale = math.min(revert_scale, 1)
	end
	gui.set_scale(self.node, vmath.vector3(revert_scale))

	if self._fit_node then
		self.fit_size = gui.get_size(self._fit_node)
		self.fit_size.x = self.fit_size.x / x_koef
		self.fit_size.y = self.fit_size.y / y_koef
	end

	x_koef = self.fit_size.x / self.origin_size.x * x_koef
	y_koef = self.fit_size.y / self.origin_size.y * y_koef

	local new_size = vmath.vector3(self.origin_size)

	if self.mode == const.LAYOUT_MODE.STRETCH then
		new_size.x = new_size.x * x_koef / revert_scale
		new_size.y = new_size.y * y_koef / revert_scale
	end

	if self.mode == const.LAYOUT_MODE.STRETCH_X then
		new_size.x = new_size.x * x_koef / revert_scale
	end

	if self.mode == const.LAYOUT_MODE.STRETCH_Y then
		new_size.y = new_size.y * y_koef / revert_scale
	end

	-- Fit to the stretched container (node size or other defined)
	if self.mode == const.LAYOUT_MODE.ZOOM_MIN then
		new_size = new_size * math.min(x_koef, y_koef)
	end
	if self.mode == const.LAYOUT_MODE.ZOOM_MAX then
		new_size = new_size * math.max(x_koef, y_koef)
	end

	--self.position.x = self.origin_position.x + self.origin_position.x * (x_koef - 1)
	--self.position.y = self.origin_position.y + self.origin_position.y * (y_koef - 1)
	--gui.set_position(self.node, self.position)

	self:set_size(new_size)
end


--- Set minimal size of layout node
-- @tparam Layout self @{Layout}
-- @tparam vector3 min_size
-- @treturn Layout @{Layout}
function Layout.set_min_size(self, min_size)
	self._min_size = min_size
	return self
end


--- Set maximum size of layout node
-- @tparam Layout self @{Layout}
-- @tparam vector3 max_size
-- @treturn Layout @{Layout}
function Layout.set_max_size(self, max_size)
	self._max_size = max_size
	return self
end


--- Set new size of layout node
-- @tparam Layout self @{Layout}
-- @tparam vector3 size
-- @treturn Layout @{Layout}
function Layout.set_size(self, size)
	if not self._inited then
		return
	end

	local new_size = const.TEMP_VECTOR
	new_size.x = size.x
	new_size.y = size.y
	new_size.z = 0

	if self._min_size then
		new_size.x = math.max(new_size.x, self._min_size.x)
		new_size.y = math.max(new_size.y, self._min_size.y)
	end

	if self._max_size then
		new_size.x = math.min(new_size.x, self._max_size.x)
		new_size.y = math.min(new_size.y, self._max_size.y)
	end

	self.center_offset = -vmath.vector3(new_size.x * self.pivot_offset.x, new_size.y * self.pivot_offset.y, 0)
	self._current_size = new_size
	gui.set_size(self.node, new_size)

	self:update_anchors()

	self.on_size_changed:trigger(self:get_context(), new_size)

	return self
end


--- Set new origin position of layout node. You should apply this on node movement
-- @tparam Layout self @{Layout}
-- @tparam vector3 new_origin_position
-- @treturn Layout @{Layout}
function Layout.set_origin_position(self, new_origin_position)
	self.origin_position = new_origin_position or self.origin_position
	self:on_window_resized()
	return self
end


--- Set new origin size of layout node. You should apply this on node manual size change
-- @tparam Layout self @{Layout}
-- @tparam vector3 new_origin_size
-- @treturn Layout @{Layout}
function Layout.set_origin_size(self, new_origin_size)
	self.origin_size = new_origin_size or self.origin_size
	self:on_window_resized()
	return self
end


--- Set max gui upscale for FIT adjust mode (or side). It happens on bigger render gui screen
-- @tparam Layout self @{Layout}
-- @tparam number max_gui_upscale
-- @treturn Layout @{Layout}
function Layout.set_max_gui_upscale(self, max_gui_upscale)
	self._max_gui_upscale = max_gui_upscale
	self:on_window_resized()
end


--- Set size for layout node to fit inside it
-- @tparam Layout self @{Layout}
-- @tparam vector3 target_size
-- @treturn Layout @{Layout}
function Layout.fit_into_size(self, target_size)
	self.fit_size = target_size
	self:on_window_resized()
	return self
end


--- Set node for layout node to fit inside it. Pass nil to reset
-- @tparam Layout self @{Layout}
-- @tparam[opt] Node node
-- @treturn Layout @{Layout}
function Layout.fit_into_node(self, node)
	self._fit_node = node
	self:on_window_resized()
	return self
end


--- Set current size for layout node to fit inside it
-- @tparam Layout self @{Layout}
-- @treturn Layout @{Layout}
function Layout.fit_into_window(self)
	return self:fit_into_size(vmath.vector3(
		gui.get_width(),
		gui.get_height(),
		0))
end


-- @tparam Layout self @{Layout}
-- @treturn Layout @{Layout} New created layout instance
function Layout.add_anchor(self, node)
	node = self:get_node(node)
	local parent_size = gui.get_size(self.node)
	local init_position = gui.get_position(node)
	init_position.x = init_position.x - self.center_offset.x
	init_position.y = init_position.y - self.center_offset.y

	local side_offset = vmath.vector4( -- left top right bottom
		parent_size.x/2 + init_position.x,
		parent_size.y/2 - init_position.y,
		parent_size.x/2 - init_position.x,
		parent_size.y/2 + init_position.y
	)

	local anchor_layout = self.druid:new_layout(node)
	table.insert(self._anchors, {
		node = node,
		layout = anchor_layout,
		init_position = init_position,
		pivot = gui.get_pivot(node),
		init_size = gui.get_size(node),
		adjust_mode = gui.get_adjust_mode(node),
		parent_size = parent_size,
		side_offset = side_offset,
	})

	gui.set_adjust_mode(node, gui.ADJUST_FIT)
	return anchor_layout
end


-- @tparam Layout self @{Layout}
-- @treturn Layout @{Layout}
function Layout.remove_anchor(self, node)
	for index = 1, #self._anchors do
		local anchor = self._anchors[index]
		if anchor.node == node then
			table.remove(self._anchors, index)
			self.druid:remove(anchor.layout)
			return
		end
	end

	return self
end


-- @tparam Layout self @{Layout}
-- @treturn Layout @{Layout}
function Layout.update_anchors(self)
	if not self._inited then
		return
	end

	for index = 1, #self._anchors do
		local child = self._anchors[index]
		local node = child.node

		--- Position update (for FIT)
		local pos = vmath.vector3(child.init_position)
		pos.x = pos.x + self.center_offset.x
		pos.y = pos.y + self.center_offset.y
		local pivot = child.pivot
		local pivot_offset = helper.get_pivot_offset(pivot)

		local stretch_side_x = self._current_size.x
		local stretch_side_y = self._current_size.y
		local fill_perc_x = child.init_size.x / child.parent_size.x
		local fill_perc_y = child.init_size.y / child.parent_size.y

		if pivot_offset.x < 0 then -- left
			pos.x = self.center_offset.x - self._current_size.x/2 + child.side_offset.x
			stretch_side_x = self._current_size.x - child.side_offset.x
			fill_perc_x = child.init_size.x / (child.parent_size.x - child.side_offset.x)
		end
		if pivot_offset.y > 0 then -- top
			pos.y = self.center_offset.y + self._current_size.y/2 - child.side_offset.y
			stretch_side_y = self._current_size.y - child.side_offset.y
			fill_perc_y = child.init_size.y / (child.parent_size.y - child.side_offset.y)
		end
		if pivot_offset.x > 0 then -- right
			pos.x = self.center_offset.x + self._current_size.x/2 - child.side_offset.z
			stretch_side_x = self._current_size.x - child.side_offset.z
			fill_perc_x = child.init_size.x / (child.parent_size.x - child.side_offset.z)
		end
		if pivot_offset.y < 0 then -- bottom
			pos.y = self.center_offset.y - self._current_size.y/2 + child.side_offset.w
			stretch_side_y = self._current_size.y - child.side_offset.w
			fill_perc_y = child.init_size.y / (child.parent_size.y - child.side_offset.w)
		end
		gui.set_position(node, pos)

		-- Size Update (for stretch)
		if child.adjust_mode == gui.ADJUST_STRETCH then
			local size = vmath.vector3(child.init_size)
			size.x = stretch_side_x * fill_perc_x
			size.y = stretch_side_y * fill_perc_y
			child.layout:set_size(size)
		end
	end
end


-- @tparam Layout self @{Layout}
-- @treturn Layout @{Layout}
function Layout.create_draggable_corners(self)
	self:clear_draggable_corners()

	local node_size = gui.get_size(self.node)
	self.pivot_offset = helper.get_pivot_offset(gui.get_pivot(self.node))
	self.center_offset = -vmath.vector3(node_size.x * self.pivot_offset.x, node_size.y * self.pivot_offset.y, 0)

	for _, corner_pivot in pairs(const.CORNER_PIVOTS) do
		local corner_offset = helper.get_pivot_offset(corner_pivot)
		local anchor_position = vmath.vector3(
			self.center_offset.x + node_size.x * corner_offset.x,
			self.center_offset.y + node_size.y * corner_offset.y,
			0)

		local new_draggable_node = gui.new_box_node(anchor_position, self.style.DRAGGABLE_CORNER_SIZE)
		gui.set_parent(new_draggable_node, self.node)
		gui.set_pivot(new_draggable_node, corner_pivot)

		self:add_anchor(new_draggable_node)
		table.insert(self._draggable_corners, new_draggable_node)

		---@type druid.drag
		local drag = self.druid:new_drag(new_draggable_node, function(_, x, y)
			self:_on_corner_drag(x, y, corner_offset)
		end)

		drag.style.DRAG_DEADZONE = 0
	end

	self:update_anchors()

	return self
end


-- @tparam Layout self @{Layout}
-- @treturn Layout @{Layout}
function Layout.clear_draggable_corners(self)
	for index = 1, #self._draggable_corners do
		local drag_component = self._draggable_corners[index]
		self.druid:remove(drag_component)
		gui.delete_node(drag_component.node)
		self:remove_anchor(drag_component.node)
	end

	self._draggable_corners = {}

	return self
end


function Layout._on_corner_drag(self, x, y, corner_offset)
	if corner_offset.x < 0 then
		x = -x
	end
	if corner_offset.y < 0 then
		y = -y
	end

	local position = gui.get_position(self.node)
	local center_pos = position

	local pivot = gui.get_pivot(self.node)
	local pivot_offset = helper.get_pivot_offset(pivot)

	center_pos.x = center_pos.x + (x * (pivot_offset.x + corner_offset.x))
	center_pos.y = center_pos.y + (y * (pivot_offset.y + corner_offset.y))
	gui.set_position(self.node, center_pos)

	local size = gui.get_size(self.node)
	size.x = size.x + x
	size.y = size.y + y
	self:set_size(size)
end


return Layout
