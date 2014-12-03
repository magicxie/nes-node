class CPU

  PC : 0 ##Program Counter
  AC : 0 ##Accumulator
  XR : 0 ##X Register
  YR : 0 ##Y Register
  SR : 0 ##Status Register
  SP : 0 ##Stack Pointer
  N : 0 ##Negative
  V : 0 ##Overflow
  U : 1 ##ignored
  B : 0 ##Break
  D : 0 ##Decimal
  I : 0 ##Interrupt (IRQ disable)
  Z : 0 ##Zero
  C : 0 ##Carry
  #16k ram
  ram : []
  ramSize : 0xFFFF
  constructor : ->
    for x in [0..@ramSize]
      @ram[x] = 0;

  #reset pc
  reset :() ->
    @PC = 0;

  #clear ram
  clear :() ->
    for x in [0..@ramSize]
      @ram[x] = 0;

 #addressing mode:
 #A		....	Accumulator	 	OPC A	 	operand is AC
  accumulator :(oper) -> @AC
 #abs		....	absolute	 	OPC $HHLL	 	operand is address $HHLL
  absolute    :(oper) -> @ram[oper]
 #abs,X		....	absolute, X-indexed	 	OPC $HHLL,X	 	operand is address incremented by X with carry
  absoluteX   :(oper) -> @ram[oper + @XR]
 #abs,Y		....	absolute, Y-indexed	 	OPC $HHLL,Y	 	operand is address incremented by Y with carry
  absoluteY   :(oper) -> @ram[oper + @YR]
 # #		....	immediate	 	OPC #$BB	 	operand is byte (BB)
  immediate :(oper) -> oper
 #impl		....	implied	 	OPC	 	operand implied
  implied :(oper) -> @AC
 #ind		....	indirect	 	OPC ($HHLL)	 	operand is effective address; effective address is value of address
  indirect :(oper) -> @ram[@ram[oper]]
 #X,ind		....	X-indexed, indirect	 	OPC ($BB,X)
 # operand is effective zeropage address; effective address is byte (BB) incremented by X without carry
  indirectX :(oper) ->  @ram[@ram[(oper  & 0x00FF) + @XR]]
 #ind,Y		....	indirect, Y-indexed	 	OPC ($LL),Y
 # operand is effective address incremented by Y with carry; effective address is word at zeropage address
  indirectY :(oper) ->  @ram[@ram[(oper  & 0x00FF) + @YR]]
 #rel		....	relative	 	OPC $BB	 	branch target is PC + offset (BB), bit 7 signifies negative offset
  relative :(oper) -> @ram[@PC + oper]
 #zpg		....	zeropage	 	OPC $LL	 	operand is of address; address hibyte : zero ($00xx)
  zeropage :(oper) -> @ram[oper & 0x00FF]
 #zpg,X		....	zeropage, X-indexed	 	OPC $LL,X
 # operand is address incremented by X; address hibyte : zero ($00xx); no page transition
  zeropageX :(oper) ->  @ram[(oper + @XR) & 0x00FF]
 #zpg,Y		....	zeropage, Y-indexed	 	OPC $LL,Y
 # operand is address incremented by Y; address hibyte : zero ($00xx); no page transition
  zeropageY :(oper) ->  @ram[(oper + @YR) & 0x00FF]

  addressing : () ->
    if arguments.length == 2
        return arguments[1]
    else
      return this.immediate

  #acc

  #补码
  toTwosComplement : (sign) ->
    #负数
    if (sign > 0x7F)
      return sign ^ 0xFF + 1;
    else
      return sign;

  #反码
  toOnesComplement : (sign) ->
    #负数
    if (sign > 0x7F)
      return sign ^ 0xFF
    else
      return sign;

  bcdAccumulate : (src, dst) ->

    tcSrc = this.toTwosComplement(src)
    tcDst = this.toTwosComplement(dst)

    console.log tcSrc,tcDst

    srcH = (tcSrc & 0xF0)/0x10;
    srcL = tcSrc & 0x0F;

    dstH = (tcDst & 0xF0)/0x10;
    dstL = tcDst & 0x0F;

    console.log 'srcH',srcH
    console.log 'srcL',srcL
    console.log 'dstH',dstH
    console.log 'dstL',dstL

    tmpL = srcL + dstL;
    carryL = 0;
    adjustL = false

    console.log 'tmpL',tmpL

    if tmpL > 0xF
      carryL = 1
      adjustL = true

    if tmpL > 0x9
      adjustL = true

    tmpH = srcH + dstH + carryL;
    carryH = 0;
    adjustH = false

    if tmpH > 0xF
      carryH = 1
      adjustH = true

    console.log 'tmpH',tmpH

    tmp = tmpH * 0x10 + (tmpL & 0x0F);

    if tmp == 0
      @Z = 1
    if adjustL
      tmp +=  0x06
    if adjustH
      tmp +=  0x60

    console.log 'tmp',tmp

    return tmp


  accumulate : (src, dst) ->
    if (@D is 1)
      return this.bcdAccumulate(src, dst)
    else
      return src + dst

  binary2bcd : (oper) ->
     parseInt(oper.toString 16)

  SED : () ->
    @D = 1

  SEC : () ->
    @C = 1

  CLC : () ->
    @C = 0

  CLD : () ->
    @D = 0

  LDA : (oper) ->

    @AC = this.addressing(arguments)(oper)


  ###
  ADC  Add Memory to Accumulator with Carry

     A + M + C -> A, C                N Z C I D V
                                      + + + - - +

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     immidiate     ADC #oper     69    2     2
     zeropage      ADC oper      65    2     3
     zeropage,X    ADC oper,X    75    2     4
     absolute      ADC oper      6D    3     4
     absolute,X    ADC oper,X    7D    3     4*
     absolute,Y    ADC oper,Y    79    3     4*
     (indirect,X)  ADC (oper,X)  61    2     6
     (indirect),Y  ADC (oper),Y  71    2     5*
  ###
  ADC : (oper) ->

    oper = this.addressing(arguments)(oper)

    @AC = this.accumulate(oper, @AC)

    console.log '@@AC',@AC

    if @C == 1 then @AC = this.accumulate(@AC, @C)
    @C = if @AC > 0xFF then  1 else 0;
    @N = if (@AC & 0x80) == 0x80 then 1 else 0;
    @Z = if @AC == 0 then 1 else 0;
    H4b = @AC / 0x10
    @V = if H4b >= -8 & H4b <= 7 then 0 else 1;
    console.log('@H4b is' + H4b.toString(16))
    console.log '@V',@V
    console.log '@C',@C
    console.log '@N',@N
    console.log '@Z',@Z

    @AC = @AC & 0xFF;

    console.log '@AC',@AC

  SBC : (oper, addressing) ->
    addressing(oper)

exports.CPU = CPU