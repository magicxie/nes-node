class CPU

  ##registers

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

  accumulate : (src, dst, carry) ->
      return src + dst + carry;

  setZ : (oper) ->
    @Z = if oper == 0 then 1 else 0;

  setN : (oper) ->
    @N = if (oper & 0x80) != 0 then 1 else 0;

  setZN : (oper) ->
    setZ(oper)
    setN(oper)

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

    @C = if @AC > 0xFF then 1 else 0;

    setZN(@AC)

    H4b = @AC / 0x10
    @V = if H4b >= -8 & H4b <= 7 then 0 else 1;
    if @V == 1
      console.warn('High 4 bit', H4b.toString(16), 'is not in rage(-8~7). Overflow!!')
    console.log('@H4b is', H4b.toString(16))

    @AC = @AC & 0xFF;

    this.printRegisters()

  SBC : (oper, addressing) ->
    addressing(oper)

exports.CPU = CPU