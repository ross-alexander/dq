---
title: Various TeX related testing
author: Ross Alexander
date: February 3, 2026
---

# Precis

This was originally created due to a bug in XeTeX [185].  It is an
issue where the font metrics are doubles while TeX uses fixed point.
In one part of the code they are converted then summed while in
another they are summed then converted.  This means the length of the
whole string != the summed length of each character, causing
individual characters to be longer than the box they are in.  This is
particularly noticable in tblr where the field is a hyphenated
negative number and TeX will line break the hyphen.

This issue was fixed in LuaTeX (it doesn't happen in PDFTeX) so moved
from using XeTeX to LuaTeX.  LuaTeX is measurably slower then XeTeX
but it produced the right result.

# fmttest

This was work to create a cleansheet style file for dq2020e.  By
assuming LuaLaTeX as the engine a lot of old checks and font handling
is no longer necessary.

