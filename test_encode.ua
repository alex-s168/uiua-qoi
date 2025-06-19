Qoi ~ "lib.ua"

##
# ◌ ⍜&fo Qoi~DecodeStreamAll "dice.qoi"
# 
# $uiuaqoi ⍜now(
#  ⍜&fo Qoi~DecodeStreamAll "dice.qoi"
# )

: $unimg ⍜now(
  ◌ °img &frab "dice.qoi"
)

.

$enc⍜now(
  Qoi~EncodeAllToBytes₁
)

⊙(
  ⊃($numby⧻
  | $dec⍜now(Qoi~DecodeAll)
  | ◌°img
  )
  ◡⋅⋅(⍤""≍)
  ⊙⊙(:⟜(⍤""≍) ◌)
)
