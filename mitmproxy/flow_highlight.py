import urwid
from mitmproxy.tools.console import flowlist, palettes


class FlowItemWithHighlight(flowlist.FlowItem):
    def __init__(self, master, flow):
        self.default_color = "heading"
        super().__init__(master, flow)
        w = self.get_text()
        urwid.WidgetWrap.__init__(self, w)

    def get_text(self):
        original_flow = super().get_text()
        palette = palettes.palettes[self.master.options.console_palette].palette(
            self.master.options.console_palette_transparent
        )
        focus_map = {item[0]: self.default_color for item in palette}
        return urwid.AttrMap(
            urwid.AttrMap(original_flow, None, focus_map), None, self.default_color
        )


class FlowHighlighter:
    def load(self, loader):
        flowlist.FlowItem = FlowItemWithHighlight


addons = [FlowHighlighter()]
