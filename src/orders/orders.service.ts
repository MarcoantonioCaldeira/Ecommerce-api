import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateOrderDto } from '../auth/dto/create-order.dto';
import { OrderResponseDto } from '../auth/dto/order-response.dto'; 
import { UpdateOrderDto } from '../auth/dto/update-order.dto'
import { plainToInstance } from 'class-transformer'; 
import { Order } from '@prisma/client'; 

@Injectable()
export class OrdersService {
  constructor(private prisma: PrismaService) {}

  async create(createOrderDto: CreateOrderDto, userId: number): Promise<OrderResponseDto> {
    console.log('Recebido createOrderDto:', JSON.stringify(createOrderDto, null, 2));

    if (!createOrderDto.items || createOrderDto.items.length === 0) {
      throw new BadRequestException('O pedido deve conter pelo menos um item.');
    }

    return this.prisma.$transaction(async (tx) => {
      const order = await tx.order.create({
        data: {
          userId,
          status: 'pending',
          totalPrice: 0, 
        },
      });

      const orderItemsData = await Promise.all(
        createOrderDto.items.map(async (item, index) => {
          console.log(`Processando item ${index}:`, JSON.stringify(item, null, 2));

          const product = await tx.product.findUnique({
            where: { id: item.productId },
          });

          if (!product) {
            throw new NotFoundException(`Produto com ID ${item.productId} não encontrado.`);
          }

          console.log(`Preparando OrderItem para Produto ID ${item.productId} com quantidade: ${item.quantity}`);

          return {
            orderId: order.id,
            productId: item.productId,
            quantity: item.quantity,
            price: product.price, 
          };
        }),
      );

      await tx.orderItem.createMany({
        data: orderItemsData,
      });

      const createdOrderItemsWithProducts = await tx.orderItem.findMany({
        where: { orderId: order.id },
        include: {
          product: {
            select: { id: true, name: true, price: true } 
          }
        }
      });

      const fullOrder = await tx.order.findUnique({
        where: { id: order.id },
        include: {
          user: {
            select: { id: true, name: true, email: true }
          },
        }
      });

      if (!fullOrder) {
          throw new NotFoundException('Pedido não encontrado após a criação. (Erro inesperado)');
      }

      const calculatedTotalPrice = createdOrderItemsWithProducts.reduce((sum, currentItem) => {
        return sum + (currentItem.price * currentItem.quantity);
      }, 0);

      await tx.order.update({
        where: { id: fullOrder.id },
        data: {
          totalPrice: parseFloat(calculatedTotalPrice.toFixed(2)),
        },
      });

      return plainToInstance(OrderResponseDto, {
        ...fullOrder,
        calculatedTotalPrice: parseFloat(calculatedTotalPrice.toFixed(2)), 
        items: createdOrderItemsWithProducts,
      });
    });
  }

  async findOne(id: number, userId: number): Promise<OrderResponseDto> {
    const order = await this.prisma.order.findUnique({
      where: { id:id, userId:userId },
      include: {
        items: {
          include: {
            product: {
              select: { id: true, name: true, price: true } 
            }
          }
        },
        user: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
      },
    });

    if (!order) {
      throw new NotFoundException(`Pedido com ID ${id} não encontrado para o usuário ${userId}.`);
    }

    const calculatedTotalPrice = order.items.reduce((sum, currentItem) => {
      return sum + (currentItem.price * currentItem.quantity);
    }, 0);

    return plainToInstance(OrderResponseDto, {
      ...order,
      calculatedTotalPrice: parseFloat(calculatedTotalPrice.toFixed(2)),
    });
  }

  async findAll(userId: number): Promise<OrderResponseDto[]> {
    const orders = await this.prisma.order.findMany({
      where: { userId },
      include: {
        items: {
          include: {
            product: {
              select: { id: true, name: true, price: true }
            },
          },
        },
        user: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
      },
    });

    return orders.map(order => {
      const calculatedTotalPrice = order.items.reduce((sum, currentItem) => {
        return sum + (currentItem.price * currentItem.quantity);
      }, 0);
      return plainToInstance(OrderResponseDto, {
        ...order,
        calculatedTotalPrice: parseFloat(calculatedTotalPrice.toFixed(2)),
      });
    });
  }

  async update(id: number, updateOrderDto: UpdateOrderDto, userId: number): Promise<Order> {
    const existingOrder = await this.prisma.order.findUnique({
      where: { id: id, userId: userId },
    });
    if (!existingOrder) {
      throw new NotFoundException(`Pedido com ID ${id} não encontrado ou não pertence ao usuário.`);
    }
    return this.prisma.order.update({
      where: { id: id, userId: userId },
      data: updateOrderDto,
    });
  }

  async remove(id: number, userId: number): Promise<Order> {
    const existingOrder = await this.prisma.order.findUnique({
      where: { id: id, userId: userId },
    });

    if (!existingOrder) {
      throw new NotFoundException(`Pedido com ID ${id} não encontrado ou não pertence ao usuário.`);
    }

    await this.prisma.orderItem.deleteMany({
      where: { orderId: id },
    });

    return this.prisma.order.delete({
      where: { id: id, userId: userId },
    });
  }
}