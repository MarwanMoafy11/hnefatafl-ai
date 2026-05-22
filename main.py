"""
main.py — Hnefatafl entry point.

  python main.py        -> Pygame GUI (game logic in Prolog)
  python main.py --cli  -> text mode (run controller.pl directly via swipl)
"""
import sys

def main():
    if "--cli" in sys.argv:
        import subprocess, os
        pl = os.path.join(os.path.dirname(os.path.abspath(__file__)), "controller.pl")
        subprocess.run(["swipl", pl])
    else:
        from gui import main as gui_main
        gui_main()

if __name__ == "__main__":
    main()
