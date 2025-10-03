from typing import List

from kitty.boss import Boss


def main(args: List[str]) -> str:
    # Return empty string to pass control to handle_result
    return ""


def handle_result(
    args: List[str], answer: str, target_window_id: int, boss: Boss
) -> None:
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return

    # Get the current scroll position
    # scrolled_by tells us how many lines we've scrolled back from the bottom
    scroll_pos = w.screen.scrolled_by

    # Get total scrollback
    lines = w.as_text(as_ansi=False, add_history=True)
    total_lines = len(lines.splitlines())

    # Calculate the line number we're currently viewing
    # If scrolled_by is 0, we're at the bottom (most recent)
    # If scrolled_by > 0, we've scrolled back that many lines
    current_line = max(1, total_lines - scroll_pos - w.screen.lines // 2)

    # Launch Neovim with scrollback content, positioned at current view
    boss.call_remote_control(
        w,
        (
            "launch",
            "--type=overlay",
            "--stdin-source=@screen_scrollback",
            "nvim",
            f"+{current_line}",
            "-c",
            "setlocal nomodifiable",
            "-",
        ),
    )


handle_result.no_ui = True
