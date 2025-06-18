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

TagRgbId ↚ °⋯⇌[1 1 1 1 1 1 1 0]
TagRgb ↚ B~M‼[0 0 0](
  B~Magic![TagRgbId]
  B~F‼B~Ube₈ (⊡0)
  B~F‼B~Ube₈ (⊡1)
  B~F‼B~Ube₈ (⊡2)
)

TagRgbaId ↚ °⋯⇌[1 1 1 1 1 1 1 1]
TagRgba ↚ B~M‼[0 0 0 0](
  B~Magic![TagRgbaId]
  B~F‼B~Ube₈ (⊡0)
  B~F‼B~Ube₈ (⊡1)
  B~F‼B~Ube₈ (⊡2)
  B~F‼B~Ube₈ (⊡3)
)

TagIdx ↚ : °⋯⇌ °□⊡1 ⊸(°0 °⋯⇌°□⊢) B~SelectByteBits![2 6] ⊃(⊢|↘1)

TagDiff ↚ : ≡◇(°⋯⇌) ↘1 ⊸(°1 °⋯⇌°□⊢) B~SelectByteBits![2 2 2 2] ⊃(⊢|↘1)

TagLuma ↚ ⊙⊂ ⊃(
  ↘2
| °⋯⇌ °□⊡1 ⊸(°2 °⋯⇌°□⊢) B~SelectByteBits![2 6] ⊡0
| ≡◇(°⋯⇌) B~SelectByteBits![4 4] ⊡1
)

TagRle ↚ : +1 °⋯⇌ °□⊡1 ⊸(°3 °⋯⇌°□⊢) B~SelectByteBits![2 6] ⊃(⊢|↘1)

Wra ↚ ◿256

# (r * 3 + g * 5 + b * 7 + a * 11) % 64
IndexHash ↚ ◿64 /(Wra+) Wra×[3 5 7 11]

~~ Decoder {
  Prev ← [0 0 0 255]
  Index ← under(pickIndexHash [0 0 0 255])([0 0 0 255]pop) ↯[64 4]0
  StreamDone ← (0)
}

# 8 bit tags have precedence over 2 bit tags
# end is marked with 7 0x00 and 1 0x01

# RemainingBytes Pixels Decoder ? Bytes Decoder
StepInner ↚ (
  ⍣(⊙([dip] ⊂: ⊡3◡⋅Decoder~Prev) TagRgb
  | dip[dip] TagRgba
  | ⊙([dip] ⊡: ◡⋅Decoder~Index) TagIdx
  | ⊙([dip] Wra+ ◡⋅Decoder~Prev⬚0↙4 -2) TagDiff
  | ⊙([dip] Wra+ ◡⋅Decoder~Prev⬚0↙4 /⊂₃ ⟜(+ -8) -32 ⊃⊢↘₁) TagLuma
  | ⊙(↯: ◡⋅Decoder~Prev) TagRle
  )

  ⊙⟜(
    ↯[4]
    ⟜°⊸Decoder~Prev
    (⍜(⊡⊙Decoder~Index)◌ IndexHash⟜:)
  )
)


# only consumes max 5 bytes per call.
# useful for streaming
# 
# RemainingBytes Pixels Decoder ? Bytes Pixels Decoder
Step ← (
  :
  ⊙(
    StepInner
    ÷255 :
  )
  :⊂
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
    ⍢Step(>=5⧻) joi :
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
  [] [] Decoder 256
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
