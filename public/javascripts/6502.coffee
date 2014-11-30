class CPU

  PC : 0 ##Program Counter#
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

  #acc
  accumulate : (oper) ->
    if (@D is 1)
      bcd = parseInt(oper.toString 16)
      if(oper < 0)
        @AC = parseInt((bcd +  parseInt((@AC.toString 16)) - !@C), 16)
        if @AC < 0
          @C = 0
          @AC = 0x9A + @AC
          @N = 1
        else
          @C = 1
          @AC = @AC & 0xFF
      else
        @AC = parseInt((bcd +  parseInt((@AC.toString 16)) + @C), 16)
        if @AC > 0x99 then @C = 1 else @C = 0
        @AC = @AC & 0xFF
    else
      if(oper < 0)
        @AC = oper + @AC - !@C
        if @AC < 0x80 && @AC >= 0
          @C = 0
          @N = 1
          @V = 0
        else if @AC >= 0x80 && @AC <= 0xFF
          @C = 1
          @N = 1
          @V = 0
        else
          @V = 1
      else
        @AC = oper + @AC + @C
        if @AC > 0xFF then @C = 1 else @C = 0
      @AC = @AC & 0xFF
    if @AC == 0 then @Z = 1 else @Z = 0
    console.log @Z,@AC

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

  LDA : (oper, addressing) ->
    @AC = addressing(oper)

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
  ADC : (oper, addressing) ->
    addressing(oper)

  SBC : (oper, addressing) ->
    addressing(oper)

exports.CPU = CPU