B ~ "git: github.com/alex-s168/uiua-bin"

#
~Header {Width Height Channels Colorspace}

HeaderBin ← B~M‼B~Z!Header (
  B~Magic![113 111 105 102]
  B~F‼B~Ule₃₂ Header~Width
  B~F‼B~Ule₃₂ Header~Height
  B~F‼B~Ube₈ Header~Channels
  B~F‼B~Ube₈ Header~Colorspace
)

Wra ↚ ◿256

# (r * 3 + g * 5 + b * 7 + a * 11) % 64
IndexHash ↚ ◿64 /+ *[3 5 7 11]

~~ Decoder {
  Prev ← [0 0 0 255]
  Index ← under(pickIndexHash [0 0 0 255])([0 0 0 255]pop) ↯[64 4]0
  StreamDone ← (0)
}

TagRgbId ↚ °⋯⇌[1 1 1 1 1 1 1 0]
TagRgbaId ↚ °⋯⇌[1 1 1 1 1 1 1 1]

TagDiff ↚  fork(drop1 | [fork(mod4floordiv16|mod4floordiv4|mod4)] first)

TagLuma ↚ [ dipdipdip0 dip(dip(+-8).) + bydip(-8) ⊃(
  floordiv16 pick1
| -32 mod64 ⊡0
| mod16 pick1
)]

# RemainingBytes Pixels Decoder ? Bytes Decoder
StepInner ↚ (
  floordiv64 first.
  sw(
    ⊃(↘1|fix ⊡: ◡⋅Decoder~Index mod64 ⊢)
  | ⊙(fix Wra+ ◡⋅Decoder~Prev⬚0↙4 -2) TagDiff
  | fork(drop2| fix Wra+ ◡⋅Decoder~Prev TagLuma)
  | ⍣(fork(drop4| fix ⊂: ⊡3◡⋅Decoder~Prev take3drop1) unTagRgbId
    | fork(drop5| fix take4drop1) unTagRgbaId
    | fork(drop1| ↯: ◡⋅Decoder~Prev +1 mod64 ⊢) pop
    ) first.
  )

  ⊙⟜(
    ↯[4]
    ⟜°⊸Decoder~Prev
    (⍜(⊡⊙Decoder~Index)◌ IndexHash⟜:)
  )
)


# only consumes max 8 bytes per call.
# useful for streaming
# 
# RemainingBytes Pixels Decoder ? Bytes Pixels Decoder
Step ← (
  sw(
    :join ⊙(
      StepInner
      ÷255 :
    ) :
  | []pop
  ) match[0 0 0 0 0 0 0 1].
)

# Bytes Pixels Decoder ? Bytes
Prep = :[] ⊙Decoder

# Pixels ? RemainingBytes Pixels Decoder
End = ⋅⊙◌

# Image ? Pixels Header
Resh = ↯⊂:4⊂∞ :⊙Header~Width

# Image ? Bytes
DecodeAll = (
  HeaderBin
  Prep
  ⍢Step(>0⧻)
  End
  Resh
)

# Buf Pixels Decoder NumReadBytes Stream ? Buf Pixels Decoder NumReadBytes Stream
DecodeStreamStep = (
  below gapgapgap&rb
  # AdditionalBuf Buf Pixels Decoder NumReadBytes Stream
  sw(
    ⍢Step(>=8⧻) joi :
  | dipdip(underDecoder~StreamDone(1pop)) pop
  ) =0 len.
)

# bool ? Buf Pixels Decoder NumReadBytes Stream
DecodeStreamContinue = (
  gapgap Decoder~StreamDone
  dippoppop
)

# Buf Pixels Decoder NumReadBytes Stream Header ? Stream
DecodeStreamStart = (
  : popHeaderBin by&rb14
  # Stream Header
  [] [] Decoder 512
)

# Image ? Buf Pixels Decoder NumReadBytes Stream Header
DecodeStreamEnd = (
  ⍢Step(>0⧻)
  un0len

  dipgapgapgapid
  # Pixels Header
  Resh
)

# Image ? Stream
DecodeStreamAll = (
  DecodeStreamStart
  ⍢DecodeStreamStep (not gapgap Decoder~StreamDone)
  DecodeStreamEnd
)
