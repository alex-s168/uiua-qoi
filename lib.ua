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
IndexHash ↚ ◿64 /+ ×[3 5 7 11]

≁Decoder {
  Prev ← [0 0 0 255]
  Index ← ⍜(⊡IndexHash [0 0 0 255])([0 0 0 255]◌) ↯[64 4]0
  StreamDone ← (0)
}

TagRgbId  ↚ °⋯⇌[1 1 1 1 1 1 1 0]
TagRgbaId ↚ °⋯⇌[1 1 1 1 1 1 1 1]

TagDiff ↚ ⊃(↘1|[⊃(◿4⌊÷16|◿4⌊÷4|◿4)] ⊢)

TagLuma ↚ [⊙⊙⊙0 ⊙(⊙(+-8).) + ⊸⊙(-8) ⊃(
    ⌊÷16 ⊡1
  | -32 ◿64 ⊡0
  | ◿16 ⊡1
  )]

# RemainingBytes Pixels Decoder ? Bytes Decoder
StepInner ↚ (
  ⌊÷64 ⊢.
  ⨬(⊃(↘1|¤ ⊡: ◡⋅Decoder~Index◿64 ⊢)
  | ⊙(¤ Wra+ ◡⋅Decoder~Prev⬚0↙4 -2) TagDiff
  | ⊃(↘2|¤ Wra+ ◡⋅Decoder~Prev TagLuma)
  | ⍣(⊃(↘4|¤ ⊂: ⊡3◡⋅Decoder~Prev↙3↘1) °TagRgbId
    | ⊃(↘5|¤ ↙4↘1) °TagRgbaId
    | ⊃(↘1|↯: ◡⋅Decoder~Prev +1 ◿64 ⊢) ◌
    ) ⊢.
  )

  ⊙⟜(
    ↯[4]
    # Pixel Decoder
    ⟜°⊸Decoder~Prev
    (⍜(⊡⊙Decoder~Index)◌ IndexHash⟜:)
  )
)

# only consumes max 8 bytes per call.
# useful for streaming
#
# RemainingBytes Pixels Decoder ? Bytes Pixels Decoder
Step ← (
  ⨬(:⊂ ⊙(
      StepInner
      ÷255 :
    ) :
  | []◌
  ) ≍[0 0 0 0 0 0 0 1].
)

# Bytes Pixels Decoder ? Bytes
Prep ← :[] ⊙Decoder

# Pixels ? RemainingBytes Pixels Decoder
End ← ⋅⊙◌

# Image ? Pixels Header
Resh ← ↯⊂:4⊂∞ :⊙Header~Width

# TODO: chunk into streams and use decode stream

# use DecodeStreamAll whenever possible instead, because of better performance
#
# Image ? Bytes
DecodeAll ← (
  HeaderBin
  Prep
  ⍢Step(>0⧻)
  End
  Resh
)

# Buf Pixels Decoder NumReadBytes Stream ? Buf Pixels Decoder NumReadBytes Stream
DecodeStreamStep ← (
  ◡⋅⋅⋅&rb
  # AdditionalBuf Buf Pixels Decoder NumReadBytes Stream
  ⨬(⍢Step(≥8⧻) ⊂ :
  | ⊙⊙(⍜Decoder~StreamDone(1◌)) ◌
  ) =0 ⧻.
)

# bool ? Buf Pixels Decoder NumReadBytes Stream
DecodeStreamContinue ← (
  ⋅⋅Decoder~StreamDone
  ⊙◌◌
)

# Buf Pixels Decoder NumReadBytes Stream Header ? Stream
DecodeStreamStart ← (
  : ◌HeaderBin⊸&rb14
  # Stream Header
  [] [] Decoder 512
)

# Image ? Buf Pixels Decoder NumReadBytes Stream Header
DecodeStreamEnd ← (
  ⍢Step(>0⧻)
  °0⧻

  ⊙⋅⋅⋅∘
  # Pixels Header
  Resh
)

# Image ? Stream
DecodeStreamAll ← (
  DecodeStreamStart
  ⍢DecodeStreamStep (¬ ⋅⋅Decoder~StreamDone)
  DecodeStreamEnd
)

~Encoder {
  Prev ← [0 0 0 255]
  Index ← ⍜(⊡IndexHash [0 0 0 255])([0 0 0 255]◌) ↯[64 4]0
  # used for multithreaded encode
  IndexValid = res[64] 1
  Rle ← 0
}

# Bytes Encoder ? Bytes Encoder
EncodeRle ↚ (
  ⍢(
    ⊙(
      ↧62 ⊸Encoder~Rle
      # NumEncThisRun Encoder
      ⟜back⍜Encoder~Rle ˜-
      -1
      +192 # 0b11xxxxxx
    )
    ⊂
    # Bytes Encoder
  )(
    ≠0 ⋅Encoder~Rle
  )
)

# Bytes Encoder ? Pixel Encoder
EncodePixel ← (
  mul◡fork(
    <992 gapEncoder~Rle
  | ≍⊙Encoder~Prev
  )
  ⨬(⊙(:EncodeRle[])
    # Pixel Encoder Bytes
    ◡(
      ⊚ mul fork(gapEncoder~IndexValid | ≡≍¤ dipEncoder~Index)
    )
    # [Idx]
    ⨬(◌
      # Pixel Encoder Bytes

      # TODO: call Wrap
      below(+2 tak3-:dipEncoder~Prev)
      # DiffRGB Pixel Encoder Bytes

      below(mul /mul mul fork(>=0|<=3) dip(=∩⊡₃ ⊙Encoder~Prev))
      sw(pop
        # TODO: luma
        # rgba
        ◡(=∩⊡₃ ⊙Encoder~Prev)
        ⨬( # rgba (alpha changed from prev)
          ⟜:
          # Pixel Encoder Pixel Bytes
          ⊙⊙(joi: ⊂255)
        | # rgb (alpha same as prev)
          ⟜:
          # Pixel Encoder Pixel Bytes
          ⊙⊙(joi:joi 254 ↙3)
        )
      | # luma
        :
        # Pixel DiffRGB Encoder Bytes
        dip(
          +64/+mul[16 4 1]
          un1<=127.
          # Byte Encoder Bytes
          dipbackjoin :
        )
      )
    | # [Idx] Pixel Encoder Bytes
      ⊙:: first
      # Pixel Encoder Idx Bytes
      ⊙⊙back⊂
    )>0⧻.
    # Pixel Encoder Bytes

    # update encoder state
    ⟜°⊸Encoder~Prev
    IndexHash⟜:
    on⍜(⊡⊙Encoder~Index)◌ 
    under(pick:Encoder~IndexValid)(1pop):

    # Encoder Bytes
    :
  | # same as prev
    ◌
    ⍜Encoder~Rle(+1)
    []
  )
)

# Bytes ? Encoder
EncodeFinish ← (
  # encode remaining rles
  ⊙◌ EncodeRle[]

  # encode end sequence
  ⊂:[0 0 0 0 0 0 0 1]
)

# color channels as bytes
#
# Bytes ? RgbaImage
EncodeAllToBytes,256 ← (
  Header :°[⊙⊙4]△ ⊙(4 0) .
  °HeaderBin[]
  ⊙(
    rowpool(|1.1
      ↯[∞ 4]
      ⊙(unbyEncoder~Prev [6969 6969 6969 6969] unbyEncoder~IndexValid res[64]0 Encoder [])
      ∧(
        # Pixel Encoder Bytes
        :EncodePixel
        # Encoder NewBytes Bytes
        dipbackjoin
      )
      :
      # Bytes Encoder 
      dippop EncodeRle
      # Bytes
    )
    # []Thread->Byte
    dip[]
    fold(
      wait
      backjoin
    )

    join:[0 0 0 0 0 0 0 1]
  )
  # HeaderBytes Bytes
  joi
)

# color channels as floats from 0 to 1
#
# Bytes ? RgbaImage
EncodeAllToBytes,1 = (
  EncodeAllToBytes,256 roundmul255
)
