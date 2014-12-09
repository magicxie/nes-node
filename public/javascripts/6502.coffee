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

  printRegisters : ()->
    console.log 'AC=',@AC,'(= BDC',@AC.toString(16),') V=',@V,'C=',@C, 'N=',@N,'Z=',@Z

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

  #补码,改为模
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

  toH4bitTowsComplement : (sign) ->
    #高四位补码
    if (sign > 0x7)
      return sign - 16;
    else
      return sign;

  bcdAccumulate : (src, dst, carry) ->

    console.log 'Start bcd accumulation'

    tcSrc = this.toTwosComplement(src)
    tcDst = this.toTwosComplement(dst)

    console.log 'Accumulate', tcSrc,'to',tcDst,'with', carry

    srcH = (tcSrc & 0xF0)/0x10;
    srcL = tcSrc & 0x0F;

    dstH = (tcDst & 0xF0)/0x10;
    dstL = tcDst & 0x0F;

    console.log 'srcH',srcH,'srcL',srcL,'is really',this.toH4bitTowsComplement(srcH), 'and',srcL
    console.log 'dstH',dstH,'dstL',dstL,'is really',this.toH4bitTowsComplement(dstH), 'and',dstL

    tmpL = srcL + dstL + carry;
    carryL = 0;
    adjustL = false

    console.log 'tmpL=',srcL,'+',dstL,'+',carry,'=',tmpL

    if tmpL > 0x9
      console.log 'Carry from low 4 bit =',tmpL
      carryL = 1
      adjustL = true

    tmpH = this.toH4bitTowsComplement(srcH) + this.toH4bitTowsComplement(dstH) + carryL;
    carryH = 0;
    adjustH = false
    #高位若负数须转换为原码
    if tmpH > 0xF
      carryH = 1
      adjustH = true

    console.log 'tmpH=',this.toH4bitTowsComplement(srcH),'+',this.toH4bitTowsComplement(dstH),'+',carryL,'=',tmpH.toString(10)

    tmp = tmpH * 0x10 + (tmpL % 0x0a);

    console.log 'tmp=',tmpH,'x 10 +',(tmpL % 0x0a),'=',tmp.toString(10)

    if tmp == 0
      @Z = 1
#    if adjustL
#      tmp +=  0x06
#    if adjustH
#      tmp +=  0x60
    return tmp


  accumulate : (src, dst, carry) ->
    if (@D is 1)
      return this.bcdAccumulate(src, dst, carry)
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

    @AC = this.accumulate(oper, @AC, @C)

    console.log '@AC',@AC

    @C = if @AC > 0xFF then  1 else 0;
    @N = if (@AC & 0x80) == 0x80 then 1 else 0;
    @Z = if @AC == 0 then 1 else 0;
    H4b = @AC / 0x10
    @V = if H4b >= -8 & H4b <= 7 then 0 else 1;
    if @V == 1
      console.warn('High 4 bit', H4b.toString(16), 'is not in rage(-8~7). Overflow!!')
    console.log('@H4b is', H4b.toString(16),)

    @AC = @AC & 0xFF;
    this.printRegisters()

  SBC : (oper, addressing) ->
    addressing(oper)

exports.CPU = CPU