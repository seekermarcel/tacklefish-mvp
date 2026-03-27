package fish

import "math/rand/v2"

type SizeVariant string

const (
	SizeMini   SizeVariant = "mini"
	SizeNormal SizeVariant = "normal"
	SizeLarge  SizeVariant = "large"
	SizeGiant  SizeVariant = "giant"
)

type ColorVariant string

const (
	ColorNormal      ColorVariant = "normal"
	ColorAlbino      ColorVariant = "albino"
	ColorMelanistic  ColorVariant = "melanistic"
	ColorRainbow     ColorVariant = "rainbow"
	ColorNeon        ColorVariant = "neon"
)

// RollSize returns a random size variant.
// Distribution: normal 70%, large 15%, mini 10%, giant 5%.
func RollSize() SizeVariant {
	roll := rand.Float64() * 100
	switch {
	case roll < 5:
		return SizeGiant
	case roll < 15:
		return SizeMini
	case roll < 30:
		return SizeLarge
	default:
		return SizeNormal
	}
}

// RollColor returns a random color variant.
// Distribution: normal 80%, albino 7%, melanistic 6%, rainbow 4%, neon 3%.
func RollColor() ColorVariant {
	roll := rand.Float64() * 100
	switch {
	case roll < 3:
		return ColorNeon
	case roll < 7:
		return ColorRainbow
	case roll < 13:
		return ColorMelanistic
	case roll < 20:
		return ColorAlbino
	default:
		return ColorNormal
	}
}
