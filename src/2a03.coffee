class CPU

  #16k ram
  RAM_SIZE : 0xFFFF

  #Constants for reset and init.
  SP_INIT_VAL : 0xFD
  PC_INIT_VAL : 0xFFFC

  BASE_STACK_ADDR : 0x100

  #interrupt vector table
  VECTOR_TABLE : {
    NMI: 0xFFFA,
    RST: 0xFFFC,
    IRQ: 0xFFFE
  }

  READ_LENGTH : {
    L : 8,
    HL : 16
  }

  ADDRESSING_MODE : {
    ACCUMULATOR : 'ACC',
    IMMEDIATE : 'IMM',
    IMPLIED : 'IMP'
  }

  constructor : (@ram = [])  ->
    for x in [0..CPU::RAM_SIZE]
      @ram[x] = 0;

    ##registers
    @PC =  CPU::PC_INIT_VAL ##Program Counter
    @AC =  0 ##Accumulator
    @XR =  0 ##X Register
    @YR =  0 ##Y Register
    @SR =  0 ##Status Register
    @SP =  CPU::SP_INIT_VAL ##Stack Pointer
    @N  =  0 ##Negative
    @V  =  0 ##Overflow
    @U  =  1 ##ignored
    @B  =  0 ##Break
    @D  =  0 ##Decimal
    @I  =  0 ##Interrupt (IRQ disable)
    @Z  =  0 ##Zero
    @C  =  0 ##Carry

    @cycles = 0

  #reset pc
  RST :() ->
    @PC = @PC_INIT_VAL
    @SP = @SP_INIT_VAL
    @cycles = 0

  #clear ram
  clear :() ->
    for x in [0..CPU::RAM_SIZE]
      @ram[x] = 0;

  #Little-end read
  read : (address, readingLength) ->

    if readingLength == CPU::READ_LENGTH.HL
      l = @ram[address];
      h = @ram[address + 1];
      h << 8 | l
    else @ram[address];

  ###
    Stack operations
  ###

  #push stack
  push :(value) ->

    if value > 0xFF
      @push(value >> 8)#High 8
      @push(value & 0xFF)#Low 8
    else
      @ram[CPU::BASE_STACK_ADDR + @SP] = value
      @SP--
      @SP &= 0xFF #overflow

  pop :() ->
    @SP++
    @SP &= 0xFF #overflow
    @ram[CPU::BASE_STACK_ADDR + @SP]

  #p register
  getP : () ->
    @N<<7 | @V<<6 | @U<<5 | @B<<4 | @D<<3 | @I<<2 | @Z<<1 | @C

  setP : (P) ->
    @N = P>>7 & 0x1
    @V = P>>6 & 0x1
    @U = P>>5 & 0x1
    @B = P>>4 & 0x1
    @D = P>>3 & 0x1
    @I = P>>2 & 0x1
    @Z = P>>1 & 0x1
    @C = P & 0x1

  ###
   Interruption
  ###

  #NMI Non-Maskable Interrupt
  NMI :() ->
    @push(@PC)

    @PC = pop()

  #IRQ
  IRQ :() ->

  printRegisters : ()->
    console.log 'AC=',@AC,'(= BDC',@AC.toString(16),') V=',@V,'C=',@C, 'N=',@N,'Z=',@Z

  #addressing mode:
  #A		....	Accumulator	 	OPC A	 	operand is AC
  accumulator :() -> {operand : @AC, address : CPU::ADDRESSING_MODE.ACCUMULATOR}

#abs		....	absolute	 	OPC $HHLL	 	operand is address $HHLL
  absolute    :(oper) -> {operand : @ram[oper], address : oper}

#abs,X		....	absolute, X-indexed	 	OPC $HHLL,X	 	operand is address incremented by X with carry
  absoluteX   :(oper) -> {operand : @ram[oper + @XR], address : oper + @XR}

#abs,Y		....	absolute, Y-indexed	 	OPC $HHLL,Y	 	operand is address incremented by Y with carry
  absoluteY   :(oper) -> {operand : @ram[oper + @YR], address : oper + @YR}

# #		....	immediate	 	OPC #$BB	 	operand is byte (BB)
  immediate :(oper) -> {operand : oper, address : CPU::ADDRESSING_MODE.IMMEDIATE}

#impl		....	implied	 	OPC	 	operand implied
  implied : (oper) -> {operand : @AC, address : CPU::ADDRESSING_MODE.IMPLIED}

#ind		....	indirect	 	OPC ($HHLL)	 	operand is effective address; effective address is value of address
  indirect :(oper) -> {operand : @ram[@ram[oper]], address : @ram[oper]}

#X,ind		....	X-indexed, indirect	 	OPC ($BB,X)
  # operand is effective zeropage address; effective address is byte (BB) incremented by X without carry
  indirectX :(oper) ->  {operand : @ram[@ram[(oper  & 0x00FF) + @XR]], address : @ram[(oper  & 0x00FF) + @XR]}

#ind,Y		....	indirect, Y-indexed	 	OPC ($LL),Y
  # operand is effective address incremented by Y with carry; effective address is word at zeropage address
  indirectY :(oper) ->  {operand : @ram[@ram[(oper  & 0x00FF) + @YR]], address : @ram[(oper  & 0x00FF) + @YR]}

#rel		....	relative	 	OPC $BB	 	branch target is PC + offset (BB), bit 7 signifies negative offset
  relative :(oper) -> {operand : @ram[@PC + oper], address : @PC + oper}

#zpg		....	zeropage	 	OPC $LL	 	operand is of address; address hibyte : zero ($00xx)
  zeropage :(oper) -> {operand : @ram[oper & 0x00FF], address : oper & 0x00FF}

#zpg,X		....	zeropage, X-indexed	 	OPC $LL,X
  # operand is address incremented by X; address hibyte : zero ($00xx); no page transition
  zeropageX :(oper) ->  {operand : @ram[(oper + @XR) & 0x00FF], address : oper + @XR};

  #zpg,Y		....	zeropage, Y-indexed	 	OPC $LL,Y
  # operand is address incremented by Y; address hibyte : zero ($00xx); no page transition
  zeropageY :(oper) ->  {operand : @ram[(oper + @YR) & 0x00FF], address : oper + @YR};

  addressing : () ->
    if arguments.length == 2
        return arguments[1]
    else
      return this.immediate

  ##cpu step info
  @stepInfo : {
    operand : 0x00,
    addressMode : null
  }

  step : () ->
    operand = @ram[@PC]
    @stepInfo.operand = operand
    @stepInfo.addressMode = this.immediate(operand)


  accumulate : (src, dst, carry) ->
      return src + dst + carry;

  setZ : (oper) ->
    @Z = if oper == 0 then 1 else 0;

  setN : (oper) ->
    @N = if (oper & 0x80) != 0 then 1 else 0;

  setZN : (oper) ->
    this.setZ(oper)
    this.setN(oper)

  addCycleOnBranch : (stepInfo) ->
    @cycles += 1;


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
  ADC : (stepInfo) ->

    operand = stepInfo.operand

    @AC = this.accumulate(operand, @AC, @C)

    console.log '@AC',@AC

    @C = if @AC > 0xFF then 1 else 0;

    this.setZN(@AC)

    H4b = @AC / 0x10
    @V = if H4b >= -8 & H4b <= 7 then 0 else 1;
    if @V == 1
      console.warn('High 4 bit', H4b.toString(16), 'is not in rage(-8~7). Overflow!!')
    console.log('@H4b is', H4b.toString(16))

    @AC = @AC & 0xFF;

    this.printRegisters()

  SBC : (stepInfo) ->

    operand = - stepInfo.operand

    @AC = this.accumulate(operand, @AC, @C)

    console.log '@AC',@AC

    @C = if @AC > 0xFF then 1 else 0;

    this.setZN(@AC)

    H4b = @AC / 0x10
    @V = if H4b >= -8 & H4b <= 7 then 0 else 1;
    if @V == 1
      console.warn('High 4 bit', H4b.toString(16), 'is not in rage(-8~7). Overflow!!')
    console.log('@H4b is', H4b.toString(16))

    @AC = @AC & 0xFF;


  ###
  AND Memory with Accumulator

     A AND M -> A                     N Z C I D V
                                      + + - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     immidiate     AND #oper     29    2     2
     zeropage      AND oper      25    2     3
     zeropage,X    AND oper,X    35    2     4
     absolute      AND oper      2D    3     4
     absolute,X    AND oper,X    3D    3     4*
     absolute,Y    AND oper,Y    39    3     4*
     (indirect,X)  AND (oper,X)  21    2     6
     (indirect),Y  AND (oper),Y  31    2     5*
  ###
  AND : (stepInfo) ->
    operand = stepInfo.operand
    @AC = @AC & operand & 0xFF
    this.setZN(@AC)

  ###
  ASL  Shift Left One Bit (Memory or Accumulator)

     C <- [76543210] <- 0             N Z C I D V
                                      + + + - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     accumulator   ASL A         0A    1     2
     zeropage      ASL oper      06    2     5
     zeropage,X    ASL oper,X    16    2     6
     absolute      ASL oper      0E    3     6
     absolute,X    ASL oper,X    1E    3     7
   ###
  ASL : (stepInfo) ->

    operand = stepInfo.operand
    addressingMode = stepInfo.addressMode

    @C = (operand >> 7) & 1
    operand <<= 1

    console.log(stepInfo,'1',addressingMode.address)

    if addressingMode.address == CPU::ADDRESSING_MODE.ACCUMULATOR
      @AC = operand
    else
      @ram[operand]

    this.setZN operand

  ###
    BCC  Branch on Carry Clear

     branch on C = 0                  N Z C I D V
                                      - - - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BCC oper      90    2     2**

  ###
  BCC : (stepInfo) ->

    if @C == 0
      @PC = stepInfo.addressMode.address;
      this.addCycleOnBranch stepInfo

  ###
    BCS  Branch on Carry Set

     branch on C = 1                  N Z C I D V
                                      - - - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BCS oper      B0    2     2**
  ###
  BCS : (stepInfo)->
    if @C == 1
      @PC = stepInfo.addressMode.address;
      this.addCycleOnBranch stepInfo;

  ###
    BEQ  Branch on Result Zero

     branch on Z = 1                  N Z C I D V
                                      - - - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BEQ oper      F0    2     2**
  ###
  BEQ : (stepInfo) ->
    if @Z == 1
      @PC = stepInfo.addressMode.address;
      this.addCycleOnBranch stepInfo;

  ###
    BIT  Test Bits in Memory with Accumulator

     bits 7 and 6 of operand are transfered to bit 7 and 6 of SR (N,V);
     the zeroflag is set to the result of operand AND accumulator.

     A AND M, M7 -> N, M6 -> V        N Z C I D V
                                     M7 + - - - M6

     addressing    assembler    opc  bytes  cycles
     --------------------------------------------
     zeropage      BIT oper      24    2     3
     absolute      BIT oper      2C    3     4

  ###
  BIT : (stepInfo) ->

    console.log stepInfo
    @N = stepInfo.operand >> 7 & 1
    @V = stepInfo.operand >> 6 & 1
    @Z = stepInfo.operand & @AC

  ###
    BMI  Branch on Result Minus

     branch on N = 1                  N Z C I D V
                                      - - - - - -

     addressing    assembler    opc  bytes  cycles
     --------------------------------------------
     relative      BMI oper      30    2     2**
  ###
  BMI : (stepInfo) ->
    if @N == 1
      @PC = stepInfo.addressMode.address;
      this.addCycleOnBranch stepInfo;

  ###
    BNE  Branch on Result not Zero

     branch on Z = 0                  N Z C I D V
                                      - - - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BNE oper      D0    2     2**
  ###
  BNE : (stepInfo) ->
    if @Z == 0
      @PC = stepInfo.addressMode.address;
      this.addCycleOnBranch stepInfo;

  ###
    BPL  Branch on Result Plus

     branch on N = 0                  N Z C I D V
                                      - - - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BPL oper      10    2     2**

  ###
  BPL : (stepInfo) ->
    if @N == 0
      @PC = stepInfo.addressMode.address;
      this.addCycleOnBranch stepInfo;

  ###
    BRK  Force Break

      interrupt,                       N Z C I D V
      push PC+2, push SR               - - - 1 - -

        addressing    assembler    opc  bytes  cyles
      --------------------------------------------
      implied       BRK           00    1     7
  ###
  BRK : (stepInfo) ->
    @I = 1
    @PC += 2



  ###
    BVC  Branch on Overflow Clear

      branch on V = 0                  N Z C I D V
    - - - - - -

    addressing    assembler    opc  bytes  cyles
    --------------------------------------------
    relative      BVC oper      50    2     2**

  ###

  ###
    BVS  Branch on Overflow Set

    branch on V = 1                  N Z C I D V
  - - - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  relative      BVC oper      70    2     2**
  ###

  ###
      CLC  Clear Carry Flag

        0 -> C                           N Z C I D V
    - - 0 - - -

    addressing    assembler    opc  bytes  cyles
    --------------------------------------------
    implied       CLC           18    1     2
  ###
  exports.CPU = CPU