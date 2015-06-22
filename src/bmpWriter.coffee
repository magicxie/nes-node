require 'fs'

class BitmapFileHeader

  magicWord : 0x4d42
  size: 0
  offset : 0

class BitMapInfoHeader
  size : 0


class RGBQuad


class BitMapInfo

  header : new BitMapInfoHeader()
  rgbQuad : new RGBQuad()

class Bitmap

  bitmapFileHeader : new BitmapFileHeader()
  bitmapInfo : new BitMapInfo()

