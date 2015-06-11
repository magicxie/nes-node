class CPU

  #16k ram
  RAM_SIZE: 0xFFFF

  #Constants for reset and init.
  SP_INIT_VAL: 0xFD
  PC_INIT_VAL: 0xFFFC

  BASE_STACK_ADDR: 0x100

  #interrupt vector table
  VECTOR_TABLE: {
    NMI: 0xFFFA,
    RST: 0xFFFC,
    IRQ: 0xFFFE
  }

  READ_LENGTH: {
    L: 8,
    HL: 16
  }

  ADDRESSING_MODE: {
    ACCUMULATOR: 'ACC',
    IMMEDIATE: 'IMM',
    IMPLIED: 'IMP'
  }

  constructor: (@ram = [])  ->
    for x in [0..CPU::RAM_SIZE]
      @ram[x] = 0;

    ##registers
    @PC = CPU::PC_INIT_VAL ##Program Counter
    @AC = 0 ##Accumulator
    @XR = 0 ##X Register
    @YR = 0 ##Y Register
    @SR = 0 ##Status Register
    @SP = CPU::SP_INIT_VAL ##Stack Pointer
    @N = 0 ##Negative
    @V = 0 ##Overflow
    @U = 1 ##ignored
    @B = 0 ##Break
    @D = 0 ##Decimal
    @I = 0 ##Interrupt (IRQ disable)
    @Z = 0 ##Zero
    @C = 0 ##Carry

    @cycles = 0

  #reset pc
  init: () ->
    @PC = @PC_INIT_VAL
    @SP = @SP_INIT_VAL
    @cycles = 0

  #clear ram
  clear: () ->
    for x in [0..CPU::RAM_SIZE]
      @ram[x] = 0;

  #Little-end read
  read: (address, readingLength) ->
    if readingLength == CPU::READ_LENGTH.HL
      l = @ram[address];
      h = @ram[address + 1];
      h << 8 | l
    else @ram[address];

  ###
    Stack operations
  ###

  #push stack
  push: (value) ->
    if value > 0xFF
      @push(value >> 8) #High 8
      @push(value & 0xFF)#Low 8
    else
      @ram[CPU::BASE_STACK_ADDR + @SP] = value
      @SP--
      @SP &= 0xFF #overflow

  pop: () ->
    @SP++
    @SP &= 0xFF #overflow
    @ram[CPU::BASE_STACK_ADDR + @SP]

  #status register
  getSR: () ->
    @N << 7 | @V << 6 | @U << 5 | @B << 4 | @D << 3 | @I << 2 | @Z << 1 | @C

  setSR: (SR) ->
    @N = SR >> 7 & 0x1
    @V = SR >> 6 & 0x1
    @U = SR >> 5 & 0x1
    @B = SR >> 4 & 0x1
    @D = SR >> 3 & 0x1
    @I = SR >> 2 & 0x1
    @Z = SR >> 1 & 0x1
    @C = SR & 0x1

  ###
   Interruption
  ###
  interrupt: (interruptType) ->
    @push(@PC)
    @push(@getSR())
    @PC = @read(interruptType, CPU::READ_LENGTH.HL)
    @I = 1
    @cycles += 7

  #NMI Non-Maskable Interrupt
  NMI: () ->
    @interrupt(CPU::VECTOR_TABLE.NMI)

  #IRQ
  IRQ: () ->
    @interrupt(CPU::VECTOR_TABLE.IRQ)

  #reset
  RST: () ->
    @interrupt(CPU::VECTOR_TABLE.RST)

  printRegisters: ()->
    console.log 'AC=', @AC, '(= BDC', @AC.toString(16), ') V=', @V, 'C=', @C, 'N=', @N, 'Z=', @Z

  ###
    Addressing modes
  ###
  #A		....	Accumulator	 	OPC A	 	operand is AC
  accumulator: () -> {operand: @AC, address: CPU::ADDRESSING_MODE.ACCUMULATOR}

  #abs		....	absolute	 	OPC $HHLL	 	operand is address $HHLL
  absolute: (oper) -> {operand: @ram[oper], address: oper}

  #abs,X		....	absolute, X-indexed	 	OPC $HHLL,X	 	operand is address incremented by X with carry
  absoluteX: (oper) -> {operand: @ram[oper + @XR], address: oper + @XR}

  #abs,Y		....	absolute, Y-indexed	 	OPC $HHLL,Y	 	operand is address incremented by Y with carry
  absoluteY: (oper) -> {operand: @ram[oper + @YR], address: oper + @YR}

  # #		....	immediate	 	OPC #$BB	 	operand is byte (BB)
  immediate: (oper) -> {operand: oper, address: CPU::ADDRESSING_MODE.IMMEDIATE}

  #impl		....	implied	 	OPC	 	operand implied
  implied: (oper) -> {operand: @AC, address: CPU::ADDRESSING_MODE.IMPLIED}

  #ind		....	indirect	 	OPC ($HHLL)	 	operand is effective address; effective address is value of address
  indirect: (oper) -> {operand: @ram[@ram[oper]], address: @ram[oper]}

  #X,ind		....	X-indexed, indirect	 	OPC ($BB,X)
  # operand is effective zeropage address; effective address is byte (BB) incremented by X without carry
  indirectX: (oper) -> {operand: @ram[@ram[(oper & 0x00FF) + @XR]], address: @ram[(oper & 0x00FF) + @XR]}

  #ind,Y		....	indirect, Y-indexed	 	OPC ($LL),Y
  # operand is effective address incremented by Y with carry; effective address is word at zeropage address
  indirectY: (oper) -> {operand: @ram[@ram[(oper & 0x00FF) + @YR]], address: @ram[(oper & 0x00FF) + @YR]}

  #rel		....	relative	 	OPC $BB	 	branch target is PC + offset (BB), bit 7 signifies negative offset
  relative: (oper) -> {operand: @ram[@PC + oper], address: @PC + oper}

  #zpg		....	zeropage	 	OPC $LL	 	operand is of address; address hibyte : zero ($00xx)
  zeropage: (oper) -> {operand: @ram[oper & 0x00FF], address: oper & 0x00FF}

  #zpg,X		....	zeropage, X-indexed	 	OPC $LL,X
  # operand is address incremented by X; address hibyte : zero ($00xx); no page transition
  zeropageX: (oper) -> {operand: @ram[(oper + @XR) & 0x00FF], address: oper + @XR};

  #zpg,Y		....	zeropage, Y-indexed	 	OPC $LL,Y
  # operand is address incremented by Y; address hibyte : zero ($00xx); no page transition
  zeropageY: (oper) -> {operand: @ram[(oper + @YR) & 0x00FF], address: oper + @YR};

  addressing: () ->
    if arguments.length == 2
      return arguments[1]
    else
      return @immediate

  ##cpu step info
  @stepInfo: {
    operand: 0x00,
    addressMode: null
  }

  step: () ->
    operand = @ram[@PC]
    @stepInfo.operand = operand
    @stepInfo.addressMode = @immediate(operand)


  accumulate: (src, dst, carry) ->
    return src + dst + carry;

  compare: (src, dest) ->
    diff = src - dest
    @setZN(diff)
    if diff >= 0
      @C = 1
    else
      @C = 0
    return diff

  setZ: (oper) ->
    @Z = if oper == 0 then 1 else 0;

  setN: (oper) ->
    @N = if (oper & 0x80) != 0 then 1 else 0;

  setZN: (oper) ->
    @setZ(oper)
    @setN(oper)

  addCycleOnBranch: (stepInfo) ->
    @cycles += 1;

  ###
    Instructions
  ###

  CLD: () ->
    @D = 0

  LDA: (oper) ->
    @AC = @addressing(arguments)(oper)


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
  ADC: (stepInfo) ->
    operand = stepInfo.operand

    @AC = @accumulate(operand, @AC, @C)

    console.log '@AC', @AC

    @C = if @AC > 0xFF then 1 else 0;

    @setZN(@AC)

    H4b = @AC / 0x10
    @V = if H4b >= -8 & H4b <= 7 then 0 else 1;
    if @V == 1
      console.warn('High 4 bit', H4b.toString(16), 'is not in rage(-8~7). Overflow!!')
    console.log('@H4b is', H4b.toString(16))

    @AC = @AC & 0xFF;

    @printRegisters()

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
  AND: (stepInfo) ->
    operand = stepInfo.operand
    @AC = @AC & operand & 0xFF
    @setZN(@AC)

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
  ASL: (stepInfo) ->
    operand = stepInfo.operand
    addressingMode = stepInfo.addressMode

    @C = (operand >> 7) & 1
    operand <<= 1

    if addressingMode.address == CPU::ADDRESSING_MODE.ACCUMULATOR
      @AC = operand
    else
      @ram[operand]

    @setZN operand

  ###
    BCC  Branch on Carry Clear

     branch on C = 0                  N Z C I D V
                                      - - - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BCC oper      90    2     2**

  ###
  BCC: (stepInfo) ->
    if @C == 0
      @PC = stepInfo.addressMode.address;
      @addCycleOnBranch stepInfo

  ###
    BCS  Branch on Carry Set

     branch on C = 1                  N Z C I D V
                                      - - - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BCS oper      B0    2     2**
  ###
  BCS: (stepInfo)->
    if @C == 1
      @PC = stepInfo.addressMode.address;
      @addCycleOnBranch stepInfo;

  ###
    BEQ  Branch on Result Zero

     branch on Z = 1                  N Z C I D V
                                      - - - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BEQ oper      F0    2     2**
  ###
  BEQ: (stepInfo) ->
    if @Z == 1
      @PC = stepInfo.addressMode.address;
      @addCycleOnBranch stepInfo;

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
  BIT: (stepInfo) ->
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
  BMI: (stepInfo) ->
    if @N == 1
      @PC = stepInfo.addressMode.address;
      @addCycleOnBranch stepInfo;

  ###
    BNE  Branch on Result not Zero

     branch on Z = 0                  N Z C I D V
                                      - - - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BNE oper      D0    2     2**
  ###
  BNE: (stepInfo) ->
    if @Z == 0
      @PC = stepInfo.addressMode.address;
      @addCycleOnBranch stepInfo;

  ###
    BPL  Branch on Result Plus

     branch on N = 0                  N Z C I D V
                                      - - - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BPL oper      10    2     2**

  ###
  BPL: (stepInfo) ->
    if @N == 0
      @PC = stepInfo.addressMode.address;
      @addCycleOnBranch stepInfo;

  ###
    BRK  Force Break

      interrupt,                       N Z C I D V
      push PC+2, push SR               - - - 1 - -

        addressing    assembler    opc  bytes  cycles
      --------------------------------------------
      implied       BRK           00    1     7
  ###
  BRK: (stepInfo) ->
    @interrupt(CPU::VECTOR_TABLE.NMI)



  ###
    BVC  Branch on Overflow Clear

      branch on V = 0                  N Z C I D V
    - - - - - -

    addressing    assembler    opc  bytes  cycles
    --------------------------------------------
    relative      BVC oper      50    2     2**

  ###
  BVC: (stepInfo) ->
    if @V == 0
      @PC = stepInfo.addressMode.address;
      @addCycleOnBranch stepInfo;

  ###
    BVS  Branch on Overflow Set

    branch on V = 1                  N Z C I D V
  - - - - - -

  addressing    assembler    opc  bytes  cycles
  --------------------------------------------
  relative      BVC oper      70    2     2**
  ###
  BVS: (stepInfo) ->
    if @V == 1
      @PC = stepInfo.addressMode.address;
      @addCycleOnBranch stepInfo;

  ###
      CLC  Clear Carry Flag

        0 -> C                           N Z C I D V
    - - 0 - - -

    addressing    assembler    opc  bytes  cycles
    --------------------------------------------
    implied       CLC           18    1     2
  ###
  CLC: (stepInfo) ->
    @C = 0
    @cycles += 2

  ###
  CLI  Clear Interrupt Disable Bit

     0 -> I                           N Z C I D V
                                      - - - 0 - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     implied       CLI           58    1     2
  ###
  CLI: (stepInfo) ->
    @I = 0
    @cycles += 2

  ###
  CLV  Clear Overflow Flag

     0 -> V                           N Z C I D V
                                      - - - - - 0

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     implied       CLV           B8    1     2
  ###
  CLV: (stepInfo) ->
    @V = 0
    @cycles += 2

  ###
    CMP  Compare Memory with Accumulator

      A - M                            N Z C I D V
                                       + + + - - -

    addressing    assembler    opc  bytes  cyles
    --------------------------------------------
    immidiate     CMP #oper     C9    2     2
    zeropage      CMP oper      C5    2     3
    zeropage,X    CMP oper,X    D5    2     4
    absolute      CMP oper      CD    3     4
    absolute,X    CMP oper,X    DD    3     4*
    absolute,Y    CMP oper,Y    D9    3     4*
    (indirect,X)  CMP (oper,X)  C1    2     6
    (indirect),Y  CMP (oper),Y  D1    2     5*
  ###
  CMP: (stepInfo) ->
    @compare(@AC, stepInfo.operand)
  ###
  CPX  Compare Memory and Index X

      X - M                            N Z C I D V
                                       + + + - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  immidiate     CPX #oper     E0    2     2
  zeropage      CPX oper      E4    2     3
  absolute      CPX oper      EC    3     4
  ###
  CPX: (stepInfo) ->
    @compare(@X, stepInfo.operand)

  ###
  CPY  Compare Memory and Index Y

      Y - M                            N Z C I D V
                                       + + + - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  immidiate     CPY #oper     C0    2     2
  zeropage      CPY oper      C4    2     3
  absolute      CPY oper      CC    3     4
  ###
  CPY: (stepInfo) ->
    @compare(@Y, stepInfo.operand)

  ###
  DEC  Decrement Memory by One

     M - 1 -> M                       N Z C I D V
                                      + + - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     zeropage      DEC oper      C6    2     5
     zeropage,X    DEC oper,X    D6    2     6
     absolute      DEC oper      CE    3     3
     absolute,X    DEC oper,X    DE    3     7
  ###
  DEC: (stepInfo) ->
    decreased = stepInfo.operand - 1
    @ram[stepInfo.addressMode.address] = decreased
    @setZN(decreased)

  ###
  DEX  Decrement Index X by One

       X - 1 -> X                       N Z C I D V
                                        + + - - - -

       addressing    assembler    opc  bytes  cyles
       --------------------------------------------
       implied       DEC           CA    1     2

  ###
  DEX: (stepInfo) ->
    @setZN(@XR--)

  ###
  DEY  Decrement Index Y by One

     Y - 1 -> Y                       N Z C I D V
                                      + + - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     implied       DEC           88    1     2

  ###
  DEY: (stepInfo) ->
    @setZN(@YR--)

  ###
  EOR  Exclusive-OR Memory with Accumulator

   A EOR M -> A                     N Z C I D V
                                    + + - - - -

   addressing    assembler    opc  bytes  cyles
   --------------------------------------------
   immidiate     EOR #oper     49    2     2
   zeropage      EOR oper      45    2     3
   zeropage,X    EOR oper,X    55    2     4
   absolute      EOR oper      4D    3     4
   absolute,X    EOR oper,X    5D    3     4*
   absolute,Y    EOR oper,Y    59    3     4*
   (indirect,X)  EOR (oper,X)  41    2     6
   (indirect),Y  EOR (oper),Y  51    2     5*
  ###
  EOR: (stepInfo) ->
    @AC ^= stepInfo.operand
    @AC &= 0xFF
    @setZN(@AC)

  ###
  INC  Increment Memory by One

  M + 1 -> M                       N Z C I D V
                                  + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  zeropage      INC oper      E6    2     5
  zeropage,X    INC oper,X    F6    2     6
  absolute      INC oper      EE    3     6
  absolute,X    INC oper,X    FE    3     7
  ###
  INC: (stepInfo) ->
    increased = stepInfo.operand + 1
    @ram[stepInfo.addressMode.address] = increased
    @setZN(increased)
  ###
  INX  Increment Index X by One

  X + 1 -> X                       N Z C I D V
                                  + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       INX           E8    1     2
  ###
  INX: (stepInfo) ->
    @setZN(@XR++)
  ###

  INY  Increment Index Y by One

  Y + 1 -> Y                       N Z C I D V
                                  + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       INY           C8    1     2
  ###
  INY: (stepInfo) ->
    @setZN(@YR++)

  ###

  JMP  Jump to New Location

  (PC+1) -> PCL                    N Z C I D V
  (PC+2) -> PCH                    - - - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  absolute      JMP oper      4C    3     3
  indirect      JMP (oper)    6C    3     5
  ###
  JMP: (stepInfo) ->
    @PC = stepInfo.operand

  ###

  JSR  Jump to New Location Saving Return Address

  push (PC+2),                     N Z C I D V
  (PC+1) -> PCL                    - - - - - -
  (PC+2) -> PCH

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  absolute      JSR oper      20    3     6
  ###
  JSP: (stepInfo) ->
    @push(@PC)
    @PC = stepInfo.operand

  ###
  LDX  Load Index X with Memory

  M -> X                           N Z C I D V
                                   + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  immidiate     LDX #oper     A2    2     2
  zeropage      LDX oper      A6    2     3
  zeropage,Y    LDX oper,Y    B6    2     4
  absolute      LDX oper      AE    3     4
  absolute,Y    LDX oper,Y    BE    3     4*
  ###
  LDX: (stepInfo) ->
    @XR = stepInfo.operand
    @setZN(@XR)
  ###

  LDY  Load Index Y with Memory

  M -> Y                           N Z C I D V
                                   + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  immidiate     LDY #oper     A0    2     2
  zeropage      LDY oper      A4    2     3
  zeropage,X    LDY oper,X    B4    2     4
  absolute      LDY oper      AC    3     4
  absolute,X    LDY oper,X    BC    3     4*
  ###
  LDY: (stepInfo) ->
    @YR = stepInfo.operand
    @setZN(@YR)

  ###
  LSR  Shift One Bit Right (Memory or Accumulator)

  0 -> [76543210] -> C             N Z C I D V
                                   - + + - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  accumulator   LSR A         4A    1     2
  zeropage      LSR oper      46    2     5
  zeropage,X    LSR oper,X    56    2     6
  absolute      LSR oper      4E    3     6
  absolute,X    LSR oper,X    5E    3     7
  ###
  LSR: (stepInfo) ->
    operand = stepInfo.operand
    addressingMode = stepInfo.addressMode

    @C = operand & 1
    operand >>= 1

    if addressingMode.address == CPU::ADDRESSING_MODE.ACCUMULATOR
      @AC = operand
    else
      @ram[operand]

    @setZN operand


  ###

  NOP  No Operation

  ---                              N Z C I D V
                                - - - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       NOP           EA    1     2
  ###
  NOP: (stepInfo) ->
    #Noop

    ###

    ORA  OR Memory with Accumulator

    A OR M -> A                      N Z C I D V
                                  + + - - - -

    addressing    assembler    opc  bytes  cyles
    --------------------------------------------
    immidiate     ORA #oper     09    2     2
    zeropage      ORA oper      05    2     3
    zeropage,X    ORA oper,X    15    2     4
    absolute      ORA oper      0D    3     4
    absolute,X    ORA oper,X    1D    3     4*
    absolute,Y    ORA oper,Y    19    3     4*
    (indirect,X)  ORA (oper,X)  01    2     6
    (indirect),Y  ORA (oper),Y  11    2     5*
    ###
  ORA: (stepInfo) ->
    @AC |= stepInfo.operand
    @setZN(@AC)

  ###

  PHA  Push Accumulator on Stack

  push A                           N Z C I D V
                                - - - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       PHA           48    1     3
  ###
  PHA: (stepInfo) ->
    @push(@AC)

  ###

  PHP  Push Processor Status on Stack

  push SR                          N Z C I D V
                                - - - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       PHP           08    1     3
  ###
  PHP: (stepInfo) ->
    @push(@getSR())

  ###

  PLA  Pull Accumulator from Stack

  pull A                           N Z C I D V
                                + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       PLA           68    1     4
  ###
  PLA: (stepInfo) ->
    @AC = @pop()
    @setZN(@AC)

  ###

  PLP  Pull Processor Status from Stack

  pull SR                          N Z C I D V
                                from stack

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       PHP           28    1     4
  ###
  PLP: (stepInfo) ->
    sr = @pop()
    @setSR(sr)

  ###

  ROL  Rotate One Bit Left (Memory or Accumulator)

  C <- [76543210] <- C             N Z C I D V
                                + + + - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  accumulator   ROL A         2A    1     2
  zeropage      ROL oper      26    2     5
  zeropage,X    ROL oper,X    36    2     6
  absolute      ROL oper      2E    3     6
  absolute,X    ROL oper,X    3E    3     7
  ###
  ROL: (stepInfo) ->
    operand = stepInfo.operand
    addressingMode = stepInfo.addressMode

    @C = (operand >> 7) & 1
    operand <<= 1
    operand += @C

    #console.log(stepInfo,'1',addressingMode.address)

    if addressingMode.address == CPU::ADDRESSING_MODE.ACCUMULATOR
      @AC = operand
    else
      @ram[operand]

    @setZN operand

  ###

  ROR  Rotate One Bit Right (Memory or Accumulator)

  C -> [76543210] -> C             N Z C I D V
                                + + + - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  accumulator   ROR A         6A    1     2
  zeropage      ROR oper      66    2     5
  zeropage,X    ROR oper,X    76    2     6
  absolute      ROR oper      6E    3     6
  absolute,X    ROR oper,X    7E    3     7
  ###
  ROR: (stepInfo) ->
    operand = stepInfo.operand
    addressingMode = stepInfo.addressMode

    topBit = operand & 1
    operand >>= 1
    operand += (topBit << 7)
    @C = topBit

    #console.log(stepInfo,'1',addressingMode.address)

    if addressingMode.address == CPU::ADDRESSING_MODE.ACCUMULATOR
      @AC = operand
    else
      @ram[operand]

    @setZN operand
  ###

  RTI  Return from Interrupt

  pull SR, pull PC                 N Z C I D V
                                from stack

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       RTI           40    1     6
  ###
  RTI: (stepInfo) ->
    @setSR(@pop())
    @PC = @pop()

  ###

  RTS  Return from Subroutine

  pull PC, PC+1 -> PC              N Z C I D V
                                - - - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       RTS           60    1     6
  ###
  RTS: (stepInfo) ->
    @PC = @pop() + 1

  ###

  SBC  Subtract Memory from Accumulator with Borrow

  A - M - C -> A                   N Z C I D V
                                + + + - - +

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  immidiate     SBC #oper     E9    2     2
  zeropage      SBC oper      E5    2     3
  zeropage,X    SBC oper,X    F5    2     4
  absolute      SBC oper      ED    3     4
  absolute,X    SBC oper,X    FD    3     4*
  absolute,Y    SBC oper,Y    F9    3     4*
  (indirect,X)  SBC (oper,X)  E1    2     6
  (indirect),Y  SBC (oper),Y  F1    2     5*
  ###
  SBC: (stepInfo) ->
    operand = -stepInfo.operand

    @AC = @accumulate(operand, @AC, @C)

    console.log '@AC', @AC

    @C = if @AC > 0xFF then 1 else 0;

    @setZN(@AC)

    H4b = @AC / 0x10
    @V = if H4b >= -8 & H4b <= 7 then 0 else 1;
    if @V == 1
      console.warn('High 4 bit', H4b.toString(16), 'is not in range(-8~7). Overflow!!')
      console.log('@H4b is', H4b.toString(16))

    @AC = @AC & 0xFF;

  ###

  SEC  Set Carry Flag

  1 -> C                           N Z C I D V
                                   - - 1 - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       SEC           38    1     2
  ###
  SEC: () ->
    @C = 1

  ###
  SED  Set Decimal Flag

  1 -> D                           N Z C I D V
                                   - - - - 1 -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       SED           F8    1     2
  ###
  SED: () ->
    @D = 1
  ###

  SEI  Set Interrupt Disable Status

  1 -> I                           N Z C I D V
                                - - - 1 - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       SEI           78    1     2
  ###
  SEI: (stepInfo) ->
    @I = 1

  ###

  STA  Store Accumulator in Memory

  A -> M                           N Z C I D V
                                   - - - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  zeropage      STA oper      85    2     3
  zeropage,X    STA oper,X    95    2     4
  absolute      STA oper      8D    3     4
  absolute,X    STA oper,X    9D    3     5
  absolute,Y    STA oper,Y    99    3     5
  (indirect,X)  STA (oper,X)  81    2     6
  (indirect),Y  STA (oper),Y  91    2     6
  ###
  STA: (stepInfo) ->
    @ram[stepInfo.addressMode.address] = @AC

  ###

  STX  Store Index X in Memory

  X -> M                           N Z C I D V
                                - - - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  zeropage      STX oper      86    2     3
  zeropage,Y    STX oper,Y    96    2     4
  absolute      STX oper      8E    3     4
  ###
  STX: (stepInfo) ->
    @ram[stepInfo.addressMode.address] = @XR
  ###

  STY  Sore Index Y in Memory

  Y -> M                           N Z C I D V
                                   - - - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  zeropage      STY oper      84    2     3
  zeropage,X    STY oper,X    94    2     4
  absolute      STY oper      8C    3     4
  ###
  STY: (stepInfo) ->
    @ram[stepInfo.addressMode.address] = @YR
  ###

  TAX  Transfer Accumulator to Index X

  A -> X                           N Z C I D V
                                   + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TAX           AA    1     2
  ###
  TAX: (stepInfo) ->
    @XR = @AC
    @setZN(@XR)

  ###

  TAY  Transfer Accumulator to Index Y

  A -> Y                           N Z C I D V
                                + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TAY           A8    1     2
  ###
  TAY: (stepInfo) ->
    @YR = @AC
    @setZN(@YR)

  ###

  TSX  Transfer Stack Pointer to Index X

  SP -> X                          N Z C I D V
                                + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TSX           BA    1     2
  ###
  TSX: (stepInfo) ->
    @XR = @SP
    @setZN(@XR)

  ###

  TXA  Transfer Index X to Accumulator

  X -> A                           N Z C I D V
                                + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TXA           8A    1     2
  ###
  TXA: (stepInfo) ->
    @AC = @R
    @setZN(@AC)

  ###

  TXS  Transfer Index X to Stack Register

  X -> SP                          N Z C I D V
                                + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TXS           9A    1     2
  ###
  TXS: (stepInfo) ->
    @SP = @XR
    @setZN(@SP)

  ###

  TYA  Transfer Index Y to Accumulator

  Y -> A                           N Z C I D V
                                + + - - - -

  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TYA           98    1     2

  ###
  TYA: (stepInfo) ->
    @AC = @YR
    @setZN(@AC)

exports.CPU = CPU