######################################################################
#
#  This is a generated Tcl script exported
#  by a user of the Altera Nios II BSP Editor.
#
#  It can be used with the Altera 'nios2-bsp' shell script '--script'
#  option to customize a new or existing BSP.
#
######################################################################
 
######################################################################
#
# Exported Linker Memory Regions 
#
######################################################################
 
delete_memory_region MEM
add_memory_region MEM MEM 32 5242848
add_memory_region MEM2 MEM 5242880 3145728
set_setting hal.linker.exception_stack_memory_region_name MEM
set_setting hal.linker.interrupt_stack_memory_region_name MEM
 
